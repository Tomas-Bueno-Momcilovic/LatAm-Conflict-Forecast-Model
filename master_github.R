#############################################################
# Master Replication File for Research on Conflict Incidence
# Tomas Bueno Momcilovic
# May 2022

# clear environment
# -------------------------------
rm(list = ls())

# Please set your user name and custom path here:
# -------------------------------

if (Sys.getenv("USERNAME") == "NAME"){
  setwd("FILE PATH")}

# If needed, install, and then load the following packages:
# -------------------------------

# Various packages for analysis and preprocessing
library(dplyr)
library(tidyr)
library(recipes)  # for matrix encoding
library(rsample)  # for train/test split
library(vip)      # for variable importance plot
library(tree)
library(ranger)
library(gamlr)
library(maps)
library(Rcpp)
# Package for train/test split
library(rsample)
# Package for classification accuracy measures
library(cutpointr)

## Function for excluding a list of variables
`%notin%` <- Negate(`%in%`)

# Run the following files
# -------------------------------

# Loading and preparing the data
source("prepare_data.R")

# Analysis
source("analyse_data.R")

# Output
source("create_tables_figures.R")

## END