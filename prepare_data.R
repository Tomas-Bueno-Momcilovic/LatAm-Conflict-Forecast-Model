# DATA PREPARATION

## Package for xlsx loading
library(xlsx)
## Package for date adjustments
library(lubridate)
## Package for combining different ISO codes
library(countrycode)
## Package for outputing tex table
library(xtable)
## Packag for rolling windows
library(runner)
## Package for melting rows into columns
library(reshape2)

## Load the ACLED dataset
acled <- read.csv("data/latinamerica.csv") %>%
  rename("iso3n" = "ISO") %>%
  ## Exclude North America except Mexico
  filter(!(REGION =="North America" & COUNTRY != "Mexico")) %>%
  ## Reduce clutter from the large text column
  select(-c("NOTES"))

## Load the JMP dataset
jmp <- read.csv("data/jmp_master.csv") %>%
  rename("water_access" = "At.least.basic") %>%
  rename("country"="ï..country")

## Load ISO codes for combining
iso_codes <- countrycode::codelist %>%
  select(iso3c, iso3n) %>%
  rename("ISO3" = iso3c)

## Load the modified acled_crop_value dataset
## Note: SPAM dataset geocoded in QGIS, then joined with ACLED
## R does not allow for an easy solution in those cases
## See README.txt for more information
crops <- read.csv(file = "data/acled_crop_value.csv")[ ,c("COUNTRY","ADMIN1","ADMIN2","ADMIN3",
                                                          "vp_crop_a_sum","vp_prop_rainfed_mean")] %>%
  # Fill in the missing data where districts = higher administrative area
  mutate(ADMIN2 = ifelse(ADMIN2=="",ADMIN1,ADMIN2)) %>%
  ## Limit rows to only non-duplicate ADMIN2 values
  ## Note: Due to ACLED-SPAM-GADM spatial join, all rows from all datasets remained
  group_by(ADMIN2) %>%
  ## Summarize by "mean" as values are same for the entire ADMIN2
  ## Note: Year is 2010 and thus constant
  summarize("crop_value_all" = mean(vp_crop_a_sum), 
            "crop_value_prop_rainfed" = mean(vp_prop_rainfed_mean))


##### CREATING A MASTER DATASET #####
## Start with JMP data
data_raw <- jmp %>%
  ## Join the numeric ISO codes by letter codes 
  left_join(., iso_codes, by = "ISO3") %>%
  ## Join the ACLED data using numeric ISO codes
  left_join(acled, ., by =c("iso3n","YEAR"="Year")) %>%
  ## Fix a recurring problem with not actually missing NA data
  select(-c(country,ISO3)) %>%
  left_join(.,iso_codes,by="iso3n") %>%
  ## Rename ISO3c and population columns for clarity
  rename("iso3c"="ISO3") %>%
  rename("population_thousands"="Population...thousands.") %>%
  ## Arrange by country-year to fill missing water_access with previous
  arrange(COUNTRY,YEAR) %>%
  fill(water_access, .direction = c("downup")) %>%
  fill(population_thousands, .direction=c("downup")) %>%
  ## Rearrange back to original position
  arrange(data_id) %>%
  ## Filter out irrelevant event subtypes
  filter(SUB_EVENT_TYPE %notin% c("Peaceful protest",
                                  "Change to group/activity",
                                  "Protest with intervention",
                                  "Disrupted weapons use",
                                  "Protest with intervention",
                                  "Other",
                                  "Non-violent transfer of territory",
                                  "Headquarters or base established",
                                  "Arrests",
                                  "Agreement")) %>%
  ## Fill in the missing data where districts = higher administrative area
  ## See: p. 28, Kuzma et al. (2020)
  mutate(ADMIN2 = ifelse(ADMIN2=="",ADMIN1,ADMIN2)) %>%
  mutate(ADMIN2 = ifelse(ADMIN2=="",COUNTRY,ADMIN2)) %>%
  ## Left join the geolocated crop data
  left_join(., crops, by = "ADMIN2") %>%
  ## Select only necessary columns
  select(c(iso3n, iso3c, EVENT_ID_CNTY, EVENT_DATE,
           EVENT_TYPE, SUB_EVENT_TYPE, FATALITIES, 
           water_access,ADMIN1, ADMIN2, COUNTRY
           ### Note: when crops are excluded, data has 100 thousand rows
           ### When included, data has 60 thousand rows
           ,crop_value_all, crop_value_prop_rainfed
  )) %>%
  ## Omit the missing data
  na.omit() %>%
  ## Format the date properly and make a month character column
  mutate(EVENT_DATE = as.Date(EVENT_DATE, format=c("%d-%b-%y"))) %>%
  mutate(month = paste0(month(EVENT_DATE),"-",year(EVENT_DATE)), label = TRUE) %>%
  mutate(date_month = as.Date(paste0("1-",month(EVENT_DATE),"-",year(EVENT_DATE)),format="%d-%m-%Y"), label = TRUE) %>%
  mutate(year = year(EVENT_DATE), label = TRUE) %>%
  ## Structure the data according to district-month
  ## Note: ADMIN0 = Country, ADMIN1 = Regions, ADMIN2 = Districts
  unite(district_month, c(ADMIN2, month))


## Placeholder for fishing for NA values
'#data_raw #%>%
  select(everything()) %>%
  summarise_all(funs(sum(is.na(.))))
  
  write.csv(data_raw, file="test.csv")
  #'


## Create a summarized and preprocessed dataset
data <- data_raw %>%
  group_by(district_month, date_month, year, 
           iso3c, iso3n, COUNTRY, EVENT_TYPE) %>%
  summarize("FATALITIES" = sum(FATALITIES), "water_access" = mean(water_access),
            "crop_value_all"= mean(crop_value_all), 
            "crop_value_prop_rainfed" =mean(crop_value_prop_rainfed)) %>%
  ## Make the y column according to the following thresholds
  ## conflict   = 10 fatalities or more
  ## conflict_5 = 5 fatalities or more
  ## conflict_1 = 1 fatality or more
  mutate(conflict = ifelse(FATALITIES >= 10,1,0)) %>%
  mutate(conflict_5 = ifelse(FATALITIES >= 5,1,0)) %>%
  mutate(conflict_1 = ifelse(FATALITIES >= 1,1,0)) %>%
  arrange(date_month)

## Create a "rolling window" (p. 28, Kuzma et al., 2020)
## denoting within 12 months of previous conflict fatalities per district/month
## Warning: the function takes ~10 minutes to finish running
data <- data %>%  
  mutate(previous_conflict = runner(
    x = .,
    k = "12 months",
    idx = "date_month", # specify column name instead df$date
    f = function(x) {
      sum(x$FATALITIES)
    }
  )
  )

## Create a binary indicator of conflict in the past 12 months
data <- data %>%
  ## Subtract the current month from the previous_conflict
  mutate(previous_conflict = previous_conflict-FATALITIES) %>%
  mutate(prev_conflict_binary = ifelse(previous_conflict >= 10,1,0))

## Create count data
counts <- data_raw %>% group_by(district_month, EVENT_TYPE) %>% summarize(count=n())
data <- data %>%
  left_join(.,counts,by=c("district_month", "EVENT_TYPE")) 

## Create a "rolling window" with counts for events per event type
## Warning!: the function takes ~10 minutes to finish running 
data <- data %>%
  mutate(prev_conflict_counts = runner(
    x = .,
    k = "12 months",
    idx = "date_month", # specify column name instead df$date
    f = function(x) {
      sum(x$count)
    }
  )
  )

## Rename for consistency
data <- data %>%
  rename(prev_conflict_sum = previous_conflict)

## Creating backups for bulky and preprocessing-intensive datasets
#write.csv(data, file = "data/backup_data.csv")
#write.csv(data_raw, file = "data/backup_data_raw.csv")


## Generate columns based on EVENT_TYPE and prev_conf combinations for final analysis
df <- as.data.frame(data) %>% 
  ## Select only relevant predictor columns
  select(c("district_month","date_month","EVENT_TYPE","water_access",
           "crop_value_all","crop_value_prop_rainfed","conflict",
           "prev_conflict_sum","prev_conflict_binary","prev_conflict_counts")) %>%
  ## "Melt" the dataset to get the adequate shape
  melt(id = c("district_month","date_month", "EVENT_TYPE","water_access",
              "crop_value_all","crop_value_prop_rainfed","conflict"),
       measure.vars = c("prev_conflict_sum","prev_conflict_binary","prev_conflict_counts")) %>%
  ## "Recast" the dataset and get EVENT_TYPE+prev_conf combinations
  dcast(district_month+date_month
        +water_access+crop_value_all
        +crop_value_prop_rainfed+conflict~EVENT_TYPE+variable,mean,fill=0) %>%
  ## Rename for easier manipulation
  rename("battle_pcsum" = "Battles_prev_conflict_sum",
         "battle_pcbin" = "Battles_prev_conflict_binary",
         "battle_pcnum" = "Battles_prev_conflict_counts",
         "explode_pcsum" = "Explosions/Remote violence_prev_conflict_sum",
         "explode_pcbin" = "Explosions/Remote violence_prev_conflict_binary",
         "explode_pcnum" = "Explosions/Remote violence_prev_conflict_counts",
         "protest_pcsum" = "Protests_prev_conflict_sum",
         "protest_pcbin" = "Protests_prev_conflict_binary",
         "protest_pcnum" = "Protests_prev_conflict_counts",
         "riot_pcsum" = "Riots_prev_conflict_sum",
         "riot_pcbin" = "Riots_prev_conflict_binary",
         "riot_pcnum" = "Riots_prev_conflict_counts",
         "strat_pcsum" = "Strategic developments_prev_conflict_sum",
         "strat_pcbin" = "Strategic developments_prev_conflict_binary",
         "strat_pcnum" = "Strategic developments_prev_conflict_counts",
         "violent_pcsum" = "Violence against civilians_prev_conflict_sum",
         "violent_pcbin" = "Violence against civilians_prev_conflict_binary",
         "violent_pcnum" = "Violence against civilians_prev_conflict_counts")

## Create backup for df
#write.csv(df, file = "data/backup_df.csv")

## OPTIONAL: Remove datasets that are irrelevant for further analysis
rm(acled,counts,crops,iso_codes,jmp,summ,summaries)