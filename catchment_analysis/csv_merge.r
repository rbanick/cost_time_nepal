# R table combination

## libraries

library.path <- .libPaths()
print(library.path)


library("dplyr", lib.loc = library.path)
library("reshape2", lib.loc = library.path)
library("forcats", lib.loc = library.path)
library("stringr", lib.loc = library.path)
library("batch", lib.loc=library.path)
library("purrr",lib.loc=library.path)
library("plyr",lib.loc=library.path)

# loadfonts()

## batch scripting setup

setwd(".") # setwd to read in file
args <- commandArgs(TRUE)
# input <- read.csv(args[1], header=TRUE)
fullpath = getwd()
type = basename(fullpath)

## listing, merging, cleaning data

lgu_names <- read.csv("LGU_names.csv",header=TRUE)
file_list=list.files(pattern="*.csv")

adm1_list <- grep("adm1",file_list,value=TRUE)
adm2_list <- grep("adm2",file_list,value=TRUE)

adm1_data <- lapply(adm1_list,read.csv)
adm2_data <- lapply(adm2_list,read.csv)

reduce_adm1 <- adm1_data %>% reduce(left_join, b="a_STATE")
reduce_adm2 <- adm2_data %>% reduce(left_join, b="a_HLCIT_CODE")

# cleanup

adm1_name = paste(type,"_adm1",sep="")
adm2_name = paste(type,"_adm2",sep="")

reduce_adm1[is.na(reduce_adm1)] <- 0
reduce_adm2[is.na(reduce_adm2)] <- 0

delete_adm1_list <- grep("adm_pop.",names(reduce_adm1),value=TRUE)
delete_adm2_list <- grep("adm_pop.",names(reduce_adm2),value=TRUE)

adm1_final <- reduce_adm1[,!(names(reduce_adm1) %in% delete_adm1_list)]
adm1_final <- adm1_final %>% select(a_STATE,everything())

adm2_final <- reduce_adm2[,!(names(reduce_adm2) %in% delete_adm2_list)]
# adm2_final <- merge(adm2_step2,lgu_names[,c("a_HLCIT_CODE","LU_Name")],by="a_HLCIT_CODE",all.x=TRUE)
adm2_final <- left_join(adm2_final,lgu_names,by="a_HLCIT_CODE")
adm2_final <- adm2_final %>% select(a_HLCIT_CODE,LU_Name,TYPE_EN,LU_Type,everything())

## export

write.csv(adm1_final,paste(adm1_name,".csv",sep=""))
write.csv(adm2_final,paste(adm2_name,".csv",sep=""))
