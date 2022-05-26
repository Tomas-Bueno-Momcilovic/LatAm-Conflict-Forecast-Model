# Data Analysis

##### TRAIN-TEST SPLIT #####

## Drop the id column
## Note: "df" name brings error in cv.tree! Dataset renamed.
## See: https://stackoverflow.com/questions/26314062/error-when-using-cv-tree
conflict_data <- df %>% select(-c(district_month))

## Split into training-test sets by periods
train <- conflict_data %>%
  filter(date_month <= "2020-12-01")
test <- conflict_data %>%
  filter(date_month > "2021-01-01")

## Measuring conflict across training and test sets
png("results/train_val_test.png", width=350, height=200)
par(mfrow=c(1,1))
barplot(c(sum(train$conflict),sum(test$conflict)),
        xlab = c("Training","Test"),
        ylab = "Num Conflicts",main = "Conflict across the sets")
dev.off()

##### DECISION TREE #####

## Generate a decision tree
pstree <- tree(conflict ~ ., data=train, mincut=1)
## Cross-validation is used to get the underlying size
cvpst <- cv.tree(pstree, K=10)
## Best tree is of size 10
cvpst[c("size","dev")]
min(cvpst$dev)
## Getting the best candidate tree
pstcut <- prune.tree(pstree, best=10)

##### RANDOM FOREST #####

## Build a random forest
carf <- ranger(conflict ~ ., data=train, 
               num.tree = 200, min.node.size = 6, max.depth = 32, write.forest=TRUE, 
               importance="impurity")
## Determining the importance of variables
sort(carf$variable.importance, decreasing=TRUE)

## Most important variables for prediction are
## 1. violent_pcnum
## 2. battle_pcnum
## 3. crop_value_prop_rainfed
## 4. crop_value_all
## 5. violent_pcsum

## Comparing the predictions
yhat.rt <- predict(pstree, test)
yhat.rf <- predict(carf, test)$predictions

conflict <- test$conflict

par(mfrow=c(1,2))
boxplot(yhat.rt ~ conflict, xlab="decision tree", ylab="prob of conflict", col=c("pink","dodgerblue"))
boxplot(yhat.rf ~ conflict, xlab="random forest", ylab="prob of conflict", col=c("pink","dodgerblue"))


##### COMPARING THE PREDICTIONS #####
## Calculate the classification accuracy for decision tree
rule <- 1/2

tp_tree <- sum( (yhat.rt>rule)[conflict==1] )/sum(yhat.rt>rule) #- true positive rate
fp_tree <- sum( (yhat.rt>rule)[conflict==0] )/sum(yhat.rt>rule) #- false positive rate
fn_tree <- sum( (yhat.rt<rule)[conflict==1] )/sum(yhat.rt<rule) #- false negative rate
tn_tree <- sum( (yhat.rt<rule)[conflict==0] )/sum(yhat.rt<rule) #- true negative rate

recall_tree <- cutpointr::recall(tp_tree, fp_tree, tn_tree, tn_tree)

## Calculate the classification accuracy for random forest
rule <- 1/2

tp_rf <- sum( (yhat.rf>rule)[conflict==1] )/sum(yhat.rf>rule) #- true positive rate
fp_rf <- sum( (yhat.rf>rule)[conflict==0] )/sum(yhat.rf>rule) #- false positive rate
fn_rf <- sum( (yhat.rf<rule)[conflict==1] )/sum(yhat.rf<rule) #- false negative rate
tn_rf <- sum( (yhat.rf<rule)[conflict==0] )/sum(yhat.rf<rule) #- true negative rate

recall_rf <- cutpointr::recall(tp_rf, fp_rf, tn_rf, tn_rf)

##### SYSTEMATIC COMPARISON #####

## Due to the rolling windows defined for each district-month individually
## We can also compare systematically without worrying of cross-contamination
## between past and current dates
conflict_data <- conflict_data %>% select(-c(date_month))

RECALL <- list(CART=NULL, RF=NULL)
rules <- list(1/5,1/3,1/2)
for(j in 1:length(rules)){
  rule <- rules[j]
  
  for(i in 1:10){
    train <- sample(1:nrow(conflict_data), round(0.8*nrow(conflict_data),0))
    conflict <- conflict_data[-train,"conflict"]
    
    # CART RECALL
    rt <- tree(conflict ~ ., data=conflict_data[train,], mincut=1)
    yhat.rt <- predict(rt, newdata=conflict_data[-train,])
    tp_tree <- sum( (yhat.rt>rule)[conflict==1] )/sum(yhat.rt>rule) #- true positive rate
    fp_tree <- sum( (yhat.rt>rule)[conflict==0] )/sum(yhat.rt>rule) #- false positive rate
    fn_tree <- sum( (yhat.rt<rule)[conflict==1] )/sum(yhat.rt<rule) #- false negative rate
    tn_tree <- sum( (yhat.rt<rule)[conflict==0] )/sum(yhat.rt<rule) #- true negative rate
    RECALL$CART <- c(RECALL$CART, recall(tp_tree, fp_tree, tn_tree, tn_tree))
    
    # RF RECALL
    rf <- ranger(conflict ~ ., data=conflict_data[train,], 
                 num.tree = 200, min.node.size = 6, max.depth = 32, write.forest=TRUE)
    yhat.rf <- predict(rf, data=conflict_data[-train,])$predictions
    tp_rf <- sum( (yhat.rf>rule)[conflict==1] )/sum(yhat.rf>rule) #- true positive rate
    fp_rf <- sum( (yhat.rf>rule)[conflict==0] )/sum(yhat.rf>rule) #- false positive rate
    fn_rf <- sum( (yhat.rf<rule)[conflict==1] )/sum(yhat.rf<rule) #- false negative rate
    tn_rf <- sum( (yhat.rf<rule)[conflict==0] )/sum(yhat.rf<rule) #- true negative rate
    RECALL$RF <- c( RECALL$RF, recall(tp_rf, fp_rf, tn_rf, tn_rf))
    
    cat(i,"-",j,",")
  } 
}

recall_df <- as.data.frame(RECALL) 
#%>% select(c(CART,RF))

# print success
print("This marks the end of the code. Thanks!")