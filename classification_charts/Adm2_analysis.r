# R table combination

## libraries

library.path <- .libPaths()
print(library.path)


library("reshape2", lib.loc = library.path)
library("forcats", lib.loc = library.path)
library("stringr", lib.loc = library.path)
library("batch", lib.loc=library.path)
library("purrr",lib.loc=library.path)
library("dplyr", lib.loc = library.path)
library("plyr", lib.loc = library.path)
library("survey",lib.loc=library.path)
library("ggplot2",lib.loc=library.path)
library("ggridges",lib.loc=library.path)
require(lattice)
require(gridExtra)
require(ggpubr)

# loadfonts()

## batch scripting setup

setwd(".") # setwd to read in file
# args <- commandArgs(TRUE)
# input <- read.csv(args[1], header=TRUE)
fullpath = getwd()
type = basename(fullpath)

## listing, merging, cleaning data

adm2_physgeo <- read.csv("adm2_physgeo.csv",header=TRUE)
file_list=list.files(pattern="*/*.csv",recursive=TRUE)
# cat <- str_extract(file_list,"[^/]*")
# fac_type <- str_extract(file_list,"(?<=_).*(?=_)")

## read in files, add columns for the category and facility type

read_csv_filename <- function(filename){
    ret <- read.csv(filename)
    ret$source <- filename #EDIT
    ret$season <- str_extract(filename,"[^/]*")
    ret$fac_type <- str_extract(filename,"(?<=_).*(?=_)")
    ret
}

## big master import

master_import <- ldply(file_list,read_csv_filename)

# reformatting 

colnames(adm2_physgeo)[2] <- "geog"

adm2_all <- master_import %>% left_join(select(adm2_physgeo,adm2_code,geog),by=c("adm2_code" = "adm2_code"))
adm2_all$fac_type <- recode(adm2_all$fac_type,"allhf" = 'All health facilities', "allhosp" = 'All hospitals', "dhq" = 'District Headquarters', "privhosp" = 'Private hospitals', "govhosp" = 'Government hospitals', "hps" = 'Health posts and sub-health posts', "banks" = 'Commercial and development banks', "fi" = "All financial institutions")
adm2_all$season <- recode(adm2_all$season,"MSN" = 'Monsoon season', "MSNW" = 'Monsoon season (walking only)', "NM" = 'Normal times', "NMW" = 'Normal times (walking only)')
adm2_all$season <- as.factor(adm2_all$season)
adm2_all$fac_type<- as.factor(adm2_all$fac_type)
colnames(adm2_all)[12] <- "geog"

# final

adm2_final <- adm2_all[order(adm2_all$adm2_code,adm2_all$trav_value),]

# adm2_final$loop <- paste(adm2_final$season,adm2_final$fac_type)


# weighting

pop_calc<- aggregate(x = adm2_final$adm_pop,
                  by = list(adm2_code = adm2_final$adm2_code),
                  FUN = mean)
pop_calc$tot_pop <- sum(pop_calc$x)
adm2_final <- adm2_final %>% left_join(select(pop_calc, tot_pop, adm2_code), by = c("adm2_code" = "adm2_code"))

pop_calc_geog <- aggregate(adm2_final$adm_pop,by=list(adm2_code = adm2_final$adm2_code,geog = adm2_final$geog),FUN=mean)
pop_calc_geog <- aggregate(pop_calc_geog$x,by=list(geog = pop_calc_geog$geog),FUN=sum)
colnames(pop_calc_geog)[2] <- "geog_pop"
adm2_physgeo <- adm2_physgeo %>% left_join(select(pop_calc_geog, geog_pop, geog), by = c("geog" = "geog"))

adm2_final <- adm2_final %>% left_join(select(pop_calc_geog, geog_pop, geog), by = c("geog" = "geog"))

province_pop <- aggregate(adm2_final$adm_pop,by=list(province = adm2_final$province,adm2_code=adm2_final$adm2_code),FUN=mean)
province_pop <- aggregate(province_pop$x,by=list(province = province_pop$province),FUN=sum)
colnames(province_pop)[2] <- "prov_pop"
adm2_final <- adm2_final %>% left_join(select(province_pop, prov_pop, province), by = c("province" = "province"))


# colnames(adm2_physgeo)[4] <- "adm_pop"

# geog_pop <- xtabs(adm_pop ~ geog + adm2_code, adm2_final)
#
# geog_pop <- adm2_final %>% group_by(geog,adm2_code) %>% summarize(geog_pop=sum(adm_pop))
# geog_pop <- geog_pop %>% group_by(geog) %>% summarize(geog_pop=sum(geog_pop))
#
# View(xtabs_test)

## aggregating and cleaning

adm2_nat_summary <- adm2_final %>% na.omit() %>% group_by(.dots=c("season","fac_type","trav_cat","trav_value"))
adm2_nat_geog_summary <- adm2_final %>% na.omit() %>% group_by(.dots=c("geog","season","fac_type","trav_cat","trav_value"))
adm2_prov_summary <- adm2_final %>% na.omit() %>% group_by(.dots=c("province","season","fac_type","trav_cat","trav_value"))
adm2_prov_geog_summary <- adm2_final %>% na.omit() %>% group_by(.dots=c("province","geog","season","fac_type","trav_cat","trav_value"))

adm2_nat_summary <- adm2_nat_summary %>% dplyr::summarize(wtd_pc_pop = sum(cat_pop,na.rm=TRUE), avg_pc_pop = mean(pc_pop,na.rm=TRUE), sd_pc_pop = sd(pc_pop), `25%`=quantile(pc_pop, probs=0.25,na.rm=TRUE), `50%`=quantile(pc_pop, probs=0.50,na.rm=TRUE), `75%`=quantile(pc_pop, probs=0.75,na.rm=TRUE), max_pc_pop=max(pc_pop,na.rm=TRUE), tot_pop = mean(tot_pop))
adm2_nat_geog_summary <- adm2_nat_geog_summary %>% dplyr::summarize(wtd_pc_pop = sum(cat_pop,na.rm=TRUE),avg_pc_pop = mean(pc_pop,na.rm=TRUE), sd_pc_pop = sd(pc_pop,na.rm=TRUE), `25%`=quantile(pc_pop, probs=0.25,na.rm=TRUE), `50%`=quantile(pc_pop, probs=0.50,na.rm=TRUE), `75%`=quantile(pc_pop, probs=0.75,na.rm=TRUE), max_pc_pop=max(pc_pop,na.rm=TRUE), tot_pop = mean(tot_pop),geog_pop=mean(geog_pop))
adm2_prov_summary <- adm2_prov_summary %>% dplyr::summarize(wtd_pc_pop = sum(cat_pop,na.rm=TRUE),avg_pc_pop = mean(pc_pop,na.rm=TRUE), sd_pc_pop = sd(pc_pop,na.rm=TRUE), `25%`=quantile(pc_pop, probs=0.25,na.rm=TRUE), `50%`=quantile(pc_pop, probs=0.50,na.rm=TRUE), `75%`=quantile(pc_pop, probs=0.75,na.rm=TRUE), max_pc_pop=max(pc_pop,na.rm=TRUE), tot_pop = mean(tot_pop), prov_pop=mean(prov_pop))
adm2_prov_geog_summary <- adm2_prov_geog_summary %>% dplyr::summarize(wtd_pc_pop = sum(cat_pop,na.rm=TRUE),avg_pc_pop = mean(pc_pop), sd_pc_pop = sd(pc_pop), `25%`=quantile(pc_pop, probs=0.25,na.rm=TRUE), `50%`=quantile(pc_pop, probs=0.50,na.rm=TRUE), `75%`=quantile(pc_pop, probs=0.75,na.rm=TRUE), max_pc_pop=max(pc_pop,na.rm=TRUE), tot_pop = mean(tot_pop),geog_pop=mean(geog_pop), prov_pop=mean(prov_pop))

adm2_nat_summary$trav_cat <- factor(adm2_nat_summary$trav_cat, levels = c("0 to 30 minutes","30 minutes to 1 hour","1 to 2 hours","2 to 4 hours","4 to 8 hours","8 to 16 hours","16 to 32 hours","> 32 hours"))  #order trav_cat in the right way
adm2_nat_summary <- adm2_nat_summary[order(adm2_nat_summary$trav_cat),]

adm2_nat_summary$wtd_pc_pop <- adm2_nat_summary$wtd_pc_pop / adm2_nat_summary$tot_pop
adm2_nat_summary$wtd_pc_pop_label <- round(adm2_nat_summary$wtd_pc_pop,digits=4)
adm2_nat_summary$loop <- paste(adm2_nat_summary$season,adm2_nat_summary$fac_type)

adm2_nat_split <- split(adm2_nat_summary,adm2_nat_summary$loop)

adm2_nat_nowalk <- adm2_nat_summary[adm2_nat_summary$season=="Normal times" | adm2_nat_summary$season=="Monsoon season",]
adm2_nat_nowalk$fac_type <- factor(adm2_nat_nowalk$fac_type)
adm2_nat_nowalk$season <- factor(adm2_nat_nowalk$season)
adm2_nat_nowalk$loop <- paste(adm2_nat_nowalk$fac_type)
adm2_nat_nowalk_split <- split(adm2_nat_nowalk,adm2_nat_nowalk$loop)


adm2_prov_summary$trav_cat <- factor(adm2_prov_summary$trav_cat, levels = c("0 to 30 minutes","30 minutes to 1 hour","1 to 2 hours","2 to 4 hours","4 to 8 hours","8 to 16 hours","16 to 32 hours","> 32 hours"))  #order trav_cat in the right way
adm2_prov_summary <- adm2_prov_summary[order(adm2_prov_summary$trav_cat),]
adm2_prov_summary$loop <- paste(adm2_prov_summary$province,adm2_prov_summary$fac_type)
adm2_prov_summary$wtd_pc_pop <- adm2_prov_summary$wtd_pc_pop / adm2_prov_summary$prov_pop
adm2_prov_summary$wtd_pc_pop_label <- round(adm2_prov_summary$wtd_pc_pop,digits=4)

adm2_prov_split <- split(adm2_prov_summary,adm2_prov_summary$loop)

adm2_prov_nowalk <- adm2_prov_summary[adm2_prov_summary$season=="Normal times" | adm2_prov_summary$season=="Monsoon season",]
adm2_prov_nowalk$loop <- paste(adm2_prov_nowalk$province,adm2_prov_nowalk$fac_type)
adm2_prov_nowalk_split <- split(adm2_prov_nowalk,adm2_prov_nowalk$loop)

adm2_nat_geog_summary$trav_cat <- factor(adm2_nat_geog_summary$trav_cat, levels = c("0 to 30 minutes","30 minutes to 1 hour","1 to 2 hours","2 to 4 hours","4 to 8 hours","8 to 16 hours","16 to 32 hours","> 32 hours"))  #order trav_cat in the right way
adm2_nat_geog_summary <- adm2_nat_geog_summary[order(adm2_nat_geog_summary$trav_cat),]

adm2_nat_geog_summary$loop <- paste(adm2_nat_geog_summary$geog,adm2_nat_geog_summary$fac_type)
adm2_nat_geog_summary$wtd_pc_pop <- adm2_nat_geog_summary$wtd_pc_pop / adm2_nat_geog_summary$geog_pop
adm2_nat_geog_summary$wtd_pc_pop_label <- round(adm2_nat_geog_summary$wtd_pc_pop,digits=4)
adm2_nat_geog_split <- split(adm2_nat_geog_summary,adm2_nat_geog_summary$loop)

adm2_nat_geog_nowalk <- adm2_nat_geog_summary[adm2_nat_geog_summary$season=="Normal times" | adm2_nat_geog_summary$season=="Monsoon season",]
adm2_nat_geog_nowalk$loop <- paste(adm2_nat_geog_nowalk$geog,adm2_nat_geog_nowalk$fac_type)
adm2_nat_geog_nowalk_split <- split(adm2_nat_geog_nowalk,adm2_nat_geog_nowalk$loop)

adm2_prov_geog_summary$trav_cat <- factor(adm2_prov_geog_summary$trav_cat, levels = c("0 to 30 minutes","30 minutes to 1 hour","1 to 2 hours","2 to 4 hours","4 to 8 hours","8 to 16 hours","16 to 32 hours","> 32 hours"))  #order trav_cat in the right way
adm2_prov_geog_summary <- adm2_prov_geog_summary[order(adm2_prov_geog_summary$trav_cat),]
adm2_prov_geog_summary$loop <- paste(adm2_prov_geog_summary$province,adm2_prov_geog_summary$fac_type)

adm2_prov_geog_summary$wtd_pc_pop <- adm2_prov_geog_summary$wtd_pc_pop / adm2_prov_geog_summary$geog_pop

## colors setup

colors <- c("0 to 30 minutes" = 'darkgreen', "30 minutes to 1 hour" = '#2ab72e', "1 to 2 hours" = 'lightgreen', "2 to 4 hours" = '#e3eb96', "4 to 8 hours" = '#f4f007', "8 to 16 hours" = '#FECC42', "16 to 32 hours" = '#f96a34', "> 32 hours" = "red")

# Working list creation method

## list creation - standard

df_plot_list=list()

for(i in 1:length(adm2_nat_split))
{
    df1 = as.data.frame(adm2_nat_split[[i]])
    df1[is.na(df1)] <- 0
    print(df1)

    filename=paste("./Charts/National - ",df1$season," - ",df1$fac_type,".jpeg",sep="")

    jpeg(filename,width=9,height=7,units="in",bg="white",quality=1,res=300,type=c("quartz")) # jpeg basic specifications.

    plotdf1 <- ggplot(data=df1,aes(trav_cat)) +
      geom_col(aes(y=wtd_pc_pop,fill=trav_cat)) +
      ggtitle(paste("Accessibility to",df1$fac_type,"\nby Population")) +
      ylab("Average travel time to nearest facility") +
      xlab("% of population") +
      theme(legend.position="none",axis.text.y = element_text(angle=30, hjust=1)) +
      scale_fill_manual(values = colors) +
      scale_y_continuous(limits=c(0,1),labels = scales::percent) +
      coord_flip()

    plotdf2 <- facet(plotdf1,facet.by="season")
    print(plotdf2)
    Sys.sleep(1)

    df_plot_list[[i]] = plotdf1

    dev.off()
}

for(i in 1:length(adm2_nat_split)) { # Another for loop, this time to save out the bar charts in lgu_list as PDFs

  df1 = as.data.frame(adm2_nat_split[[i]])
  df1[is.na(df1)] <- 0

  filename=paste("./Charts/National - ",df1$season," - ",df1$fac_type,".jpeg",sep="")

  jpeg(filename,width=9,height=7,units="in",bg="white",quality=1,res=300,type=c("quartz")) # jpeg basic specifications. Modify the width and height here.

  print(df_plot_list[[i]])

  dev.off()
  }

## list creation - province

df_prov_plot_list=list()

for(i in 1:length(adm2_prov_split))
{
    df1 = as.data.frame(adm2_prov_split[[i]])
    df1[is.na(df1)] <- 0
    print(df1)

    filename=paste("./Charts/Province by Pop/Province ",df1$province," - ",df1$season," - ",df1$fac_type,".jpeg",sep="")

    jpeg(filename,width=9,height=7,units="in",bg="white",quality=1,res=300,type=c("quartz")) # jpeg basic specifications.

    plotdf1 <- ggplot(data=df1,aes(trav_cat)) +
      geom_col(aes(y=wtd_pc_pop,fill=trav_cat)) +
      ggtitle(paste("Province ",df1$province,"\nAccessibility to",df1$fac_type,"\nby Population")) +
      ylab("Average travel time to nearest facility") +
      xlab("% of population") +
      theme(legend.position="none",axis.text.y = element_text(angle=30, hjust=1)) +
      scale_fill_manual(values = colors) +
      scale_y_continuous(limits=c(0,1),labels = scales::percent) +
      coord_flip()

    print(plotdf1)
    Sys.sleep(1)
    df_prov_plot_list_nowalk[[i]] = plotdf1

    dev.off()
}

for(i in 1:length(adm2_prov_split)) { # Another for loop, this time to save out the bar charts in lgu_list as PDFs

  df1 = as.data.frame(adm2_prov_split[[i]])
  df1[is.na(df1)] <- 0

  filename=paste("./Charts/Province ",df1$province," - ",df1$season," - ",df1$fac_type,".jpeg",sep="")

  jpeg(filename,width=9,height=7,units="in",bg="white",quality=1,res=300,type=c("quartz")) # jpeg basic specifications. Modify the width and height here.

  print(df_prov_plot_list[[i]])

  dev.off()
  }

## list creation - geog

adm2_nat_geog_summary$loop <- paste(adm2_nat_geog_summary$geog,adm2_nat_geog_summary$season,adm2_nat_geog_summary$fac_type)

adm2_nat_geog_split <- split(adm2_nat_geog_summary,adm2_nat_geog_summary$loop)

df_geog_plot_list=list()

for(i in 1:length(adm2_nat_geog_split))
{
    df1 = as.data.frame(adm2_nat_geog_split[[i]])
    df1[is.na(df1)] <- 0
    print(df1)

    # filename=paste("./Charts/National - ",df1$season," - ",df1$fac_type,".jpeg",sep="")
    #
    # jpeg(filename,width=9,height=7,units="in",bg="white",quality=1,res=300,type=c("quartz")) # jpeg basic specifications.

    plotdf1 <- ggplot(data=df1,aes(trav_cat)) +
      geom_col(aes(y=wtd_pc_pop,fill=trav_cat)) +
      ggtitle(paste(df1$geog,"\nAccessibility to",df1$fac_type,"\nby Population")) +
      ylab("Average travel time to nearest facility") +
      xlab("% of population") +
      theme(legend.position="none",axis.text.y = element_text(angle=30, hjust=1)) +
      scale_fill_manual(values = colors) +
      scale_y_continuous(limits=c(0,1),labels = scales::percent) +
      coord_flip()
    # print(plotdf1)
    # Sys.sleep(1)
    df_geog_plot_list[[i]] = plotdf1

}


## Working error bar method

#### national

df_plot_nowalk_list=list()

for(i in 1:length(adm2_nat_nowalk_split))
{
  df1 = as.data.frame(adm2_nat_nowalk_split[[i]])
  df1[is.na(df1)] <- 0
  print(df1)

  filename=paste("./Charts/National - ",df1$fac_type,".jpeg",sep="")

  jpeg(filename,width=9,height=7,units="in",bg="white",quality=1,res=300,type=c("quartz")) # jpeg basic specifications.

  plotdf1 <- ggplot(data=df1[df1$season=="Normal times",],aes(trav_cat)) +
    geom_col(aes(y=wtd_pc_pop,fill=trav_cat)) +
    geom_errorbar(data = df1[df1$season=="Monsoon season",], aes(ymax=wtd_pc_pop, ymin=wtd_pc_pop), size=.6, width=.75,colour="red") +
    geom_text(data = df1[df1$season=="Normal times",],aes(label = paste((wtd_pc_pop_label*100),"%\n",sep=""), y = wtd_pc_pop_label), hjust = -.5) +
    geom_text(data = df1[df1$season=="Monsoon season",],aes(label = paste((wtd_pc_pop_label*100),"%",sep=""), y = wtd_pc_pop_label), hjust = -.5,vjust=1,color="red") +
    ggtitle(paste("Accessibility to ",df1$fac_type,"\nby Population",sep=""),paste(format(df1$tot_pop,big.mark=",",scientific=FALSE),"persons")) +
    xlab("Average travel time to nearest facility") +
    ylab("% of population") +
    theme(legend.position="none",axis.text.y = element_text(angle=30, hjust=1)) +
    scale_fill_manual(values = colors) +
    scale_y_continuous(limits=c(0,1),labels = scales::percent) +
    coord_flip()

  # plotdf2 <- facet(plotdf1,facet.by="season")
  # print(plotdf1)
  # Sys.sleep(1)

  df_plot_nowalk_list[[i]] = plotdf1

  dev.off()
}

for(i in 1:length(adm2_nat_nowalk_split)) { # Another for loop, this time to save out the bar charts in lgu_list as PDFs

  df1 = as.data.frame(adm2_nat_nowalk_split[[i]])
  df1[is.na(df1)] <- 0

  filename=paste("./Charts/National - ",df1$fac_type,".jpeg",sep="")

  jpeg(filename,width=9,height=7,units="in",bg="white",quality=1,res=300,type=c("quartz")) # jpeg basic specifications. Modify the width and height here.

  print(df_plot_nowalk_list[[i]])

  dev.off()
}

#### provincial

df_prov_plot_nowalk_list=list()

for(i in 1:length(adm2_prov_nowalk_split))
{
    df1 = as.data.frame(adm2_prov_nowalk_split[[i]])
    df1[is.na(df1)] <- 0
    print(df1)

    filename=paste("./Charts/Province - ",df1$province," - ",df1$fac_type,".jpeg",sep="")

    jpeg(filename,width=9,height=7,units="in",bg="white",quality=1,res=300,type=c("quartz")) # jpeg basic specifications.

    plotprovdf1 <- ggplot(data=df1[(df1$season=="Normal times"),],aes(trav_cat)) +
      geom_col(aes(y=wtd_pc_pop,fill=trav_cat)) +
      geom_errorbar(data = df1[df1$season=="Monsoon season",], aes(ymax=wtd_pc_pop, ymin=wtd_pc_pop), size=.6, width=.75,colour="red") +
      geom_text(data = df1[df1$season=="Normal times",],aes(label = paste((wtd_pc_pop_label*100),"%\n",sep=""), y = wtd_pc_pop_label), hjust = -.5) +
      geom_text(data = df1[df1$season=="Monsoon season",],aes(label = paste((wtd_pc_pop_label*100),"%",sep=""), y = wtd_pc_pop_label), hjust = -.5,vjust=1,color="red") +
      ggtitle(paste("Province - ",df1$province,"\nAccessibility to ",df1$fac_type,"\nby Population",sep=""),paste(format(df1$prov_pop,big.mark=",",scientific=FALSE),"persons")) +
      xlab("Average travel time to nearest facility") +
      ylab("% of population") +
      theme(legend.position="none",axis.text.y = element_text(angle=30, hjust=1)) +
      scale_fill_manual(values = colors) +
      scale_y_continuous(limits=c(0,1),labels = scales::percent) +
      coord_flip()

    # plotdf2 <- facet(plotdf1,facet.by="season")
    # print(plotprovdf1)
    # Sys.sleep(1)

    df_prov_plot_nowalk_list[[i]] = plotprovdf1

    dev.off()
}

for(i in 1:length(adm2_prov_nowalk_split)) {

  df1 = as.data.frame(adm2_prov_nowalk_split[[i]])
  df1[is.na(df1)] <- 0

  filename=paste("./Charts/Province - ",df1$province," - ",df1$fac_type,".jpeg",sep="")

  jpeg(filename,width=9,height=7,units="in",bg="white",quality=1,res=300,type=c("quartz")) # jpeg basic specifications. Modify the width and height here.

  print(df_prov_plot_nowalk_list[[i]])

  dev.off()
}

#### geog

df_nat_geog_nowalk_list=list()

for(i in 1:length(adm2_nat_geog_nowalk_split))
{
  df1 = as.data.frame(adm2_nat_geog_nowalk_split[[i]])
  df1[is.na(df1)] <- 0
  print(df1)
  
  filename=paste("./Charts/",df1$geog," - ",df1$fac_type,".jpeg",sep="")
  
  jpeg(filename,width=9,height=7,units="in",bg="white",quality=1,res=300,type=c("quartz")) # jpeg basic specifications.
  
  plotgeogdf1 <- ggplot(data=df1[(df1$season=="Normal times"),],aes(trav_cat)) +
    geom_col(aes(y=wtd_pc_pop,fill=trav_cat)) +
    geom_errorbar(data = df1[df1$season=="Monsoon season",], aes(ymax=wtd_pc_pop, ymin=wtd_pc_pop), size=.6, width=.75,colour="red") +
    geom_text(data = df1[df1$season=="Normal times",],aes(label = paste((wtd_pc_pop_label*100),"%\n",sep=""), y = wtd_pc_pop_label), hjust = -.5) +
    geom_text(data = df1[df1$season=="Monsoon season",],aes(label = paste((wtd_pc_pop_label*100),"%",sep=""), y = wtd_pc_pop_label), hjust = -.5,vjust=1,color="red") +
    ggtitle(paste(df1$geog,"\nAccessibility to ",df1$fac_type,"\nby Population",sep=""),paste(format(df1$geog_pop,big.mark=",",scientific=FALSE),"persons")) +
    xlab("Average travel time to nearest facility") +
    ylab("% of population") +
    theme(legend.position="none",axis.text.y = element_text(angle=30, hjust=1)) +
    scale_fill_manual(values = colors) +
    scale_y_continuous(limits=c(0,1),labels = scales::percent) +
    coord_flip()
  
  # plotdf2 <- facet(plotdf1,facet.by="season")
  print(plotgeogdf1)
  # Sys.sleep(1)
  
  df_nat_geog_nowalk_list[[i]] = plotgeogdf1
  
  dev.off()
}

for(i in 1:length(adm2_nat_geog_nowalk_split)) {
  
  df1 = as.data.frame(adm2_nat_geog_nowalk_split[[i]])
  df1[is.na(df1)] <- 0
  
  filename=paste("./Charts/",df1$geog," - ",df1$fac_type,".jpeg",sep="")
  
  jpeg(filename,width=9,height=7,units="in",bg="white",quality=1,res=300,type=c("quartz")) # jpeg basic specifications. Modify the width and height here.
  
  print(df_nat_geog_nowalk_list[[i]])
  
  dev.off()
}

## Ridge creation national (by non-walking season) -- filter method -- facets work!!

## national

adm2_nat_summary_melt <- melt(adm2_nat_summary,id.vars=c("season","fac_type","trav_cat","trav_value"),measure.vars=c("wtd_pc_pop","avg_pc_pop","sd_pc_pop","max_pc_pop"))

adm2_nowalk <- adm2_final[adm2_final$season=="Normal times" | adm2_final$season=="Monsoon season",]
adm2_nowalk$trav_cat <- factor(adm2_nowalk$trav_cat, levels = c("0 to 30 minutes","30 minutes to 1 hour","1 to 2 hours","2 to 4 hours","4 to 8 hours","8 to 16 hours","16 to 32 hours","> 32 hours"))  #order trav_cat in the right way
adm2_nowalk$season <- factor(adm2_nowalk$season,levels=c("Normal times","Monsoon season"))
adm2_nowalk_melt <- melt(adm2_nowalk,id.vars=c("season","fac_type","trav_cat","adm2_code","tot_pop","adm_pop"),measure.vars="pc_pop")
#adm2_nowalk_melt = ddply(adm2_nowalk_melt, .(season,fac_type,trav_cat), transform, season_fc_sd = round(sd(value,na.rm=TRUE)*100,digits=2))
#adm2_nowalk_melt$trav_label <- paste(adm2_nowalk_melt$trav_cat,adm2_nowalk_melt$season_fc_sd)

df_ridge_nowalk_list=list()


for(i in factor(adm2_nowalk_melt$fac_type)) {
    
    adm2_nowalk_filter <- filter(adm2_nowalk_melt, fac_type == i)
    # adm2_nowalk_filter <- droplevels(adm2_nat_summary_filter)
    # str(adm2_nowalk_filter$adm2_code)
    
    print(head(adm2_nowalk_filter))

  filename=paste("./Charts/LGU comparison - ",adm2_nowalk_filter$fac_type,".jpeg",sep="")
  
  jpeg(filename,width=7,height=7,units="in",bg="white",quality=1,res=300,type=c("quartz")) # jpeg basic specifications.
  
  plotrg1 <- ggplot(adm2_nowalk_filter,aes(x=value,y=trav_cat, fill=trav_cat),trim=TRUE) +
    scale_fill_manual(values=colors) +
    ggtitle(paste("Average travel times to ",adm2_nowalk_filter$fac_type,"\nDensity plot of local government averages, per category",sep=""),paste("Median LGU population:",format(median(adm2_nowalk_filter$adm_pop,na.rm=TRUE),big.mark=",",scientific=FALSE))) +
    # ylab("Average travel time to nearest facility",vjust=-3) +
    xlab("Average % of LGU population") +
    geom_density_ridges(
      rel_min_height=0.01,scale=1,
      jittered_points = TRUE,
      position=position_points_jitter(width=0, height=0.01,adjust_vlines=TRUE),point_shape="|",point_size=1.5,point_alpha=0.5, alpha=0.5) +
    theme_ridges() +
    theme(legend.position="none",axis.text.y = element_text(angle=45, hjust=1),axis.title.y=element_blank()) +
    stat_density_ridges(quantile_lines = TRUE,quantiles=c(0.25,0.5,0.75),alpha=0.7,scale=1) +
    scale_x_continuous(limits=c(0,1),labels = scales::percent) +
    facet_wrap(~season)
  
  print(plotrg1)
  
  df_ridge_nowalk_list[[i]] = plotrg1
  
  dev.off()
}

for (i in adm2_nowalk_melt$fac_type) { # Another for loop, this time to save out the bar charts in lgu_list as PDFs
  adm2_nowalk_filter <- filter(adm2_nowalk_melt, fac_type == i)
  
  filename=paste("./Charts/LGU comparison - ",adm2_nowalk_filter$fac_type,".jpeg",sep="") # Make the file name for each PDF. The paste makes the name a variable of the facility type
  
  jpeg(filename,width=6.5,height=7,units="in",bg="white",quality=1,res=300,type=c("quartz")) # jpeg basic specifications. Modify the width and height here.
  
  print(df_ridge_nowalk_list[[i]])
  
  dev.off()
}

## geog

adm2_norm_geog <- adm2_final[adm2_final$season=="Normal times",]
adm2_norm_geog$trav_cat <- factor(adm2_norm_geog$trav_cat, levels = c("0 to 30 minutes","30 minutes to 1 hour","1 to 2 hours","2 to 4 hours","4 to 8 hours","8 to 16 hours","16 to 32 hours","> 32 hours"))  #order trav_cat in the right way
adm2_norm_geog$geog <- factor(adm2_norm_geog$geog, levels = c("Terai","Shivalik","Hill","Mountain","High Mountain"))  #order geog in the right way
adm2_norm_geog <- adm2_norm_geog %>% 
  group_by(geog,fac_type) %>%
  mutate(geog_count = length(unique(adm2_code))) %>%
  ungroup() %>%
  mutate(geog_label = paste0(geog, "; n=", geog_count," P:",prettyNum(geog_pop,big.mark=",",scientific=FALSE,digits=4)))
#stuff <- adm2_norm_geog %>% 
# group_by(geog,adm2_code) %>%
# mutate(geog_pop = sum(adm_pop)) %>%  ungroup()
# adm2_norm_geog$geog_label <- factor(adm2_norm_geog$geog_label, levels = c("Terai; n=239","Shivalik; n=65","Hill; n=314","Mountain; n=119","High Mountain; n=38"))  #order geog_label in the right way
adm2_norm_geog$geog_label <- factor(adm2_norm_geog$geog_label, levels = c("Terai; n=239 P:12,140,581","Shivalik; n=65 P:3,521,062","Hill; n=314 P:11,184,214","Mountain; n=119 P:2,015,337","High Mountain; n=38 P:305,838"))  #order geog_label in the right way
adm2_norm_geog_melt <- melt(adm2_norm_geog,id.vars=c("geog","fac_type","trav_cat","adm2_code","tot_pop","adm_pop","geog_pop","geog_label"),measure.vars="pc_pop")

#adm2_norm_geog_melt = ddply(adm2_norm_geog_melt, .(season,fac_type,trav_cat), transform, fc_sd = round(sd(value,na.rm=TRUE)*100,digits=2))
#adm2_norm_geog_melt$trav_label <- paste(adm2_norm_geog_melt$trav_cat,adm2_norm_geog_melt$fc_sd)

df_ridge_nowalk_list=list()

dev.off()
for(i in factor(adm2_norm_geog_melt$fac_type)) {
  
  adm2_norm_geog_filter <- filter(adm2_norm_geog_melt, fac_type == i)
  # adm2_norm_geog_filter <- droplevels(adm2_nat_summary_filter)
  # str(adm2_norm_geog_filter$adm2_code)
  
  print(head(adm2_norm_geog_filter))
  
  filename=paste("./Charts/Physiogeographic LGU comparison - ",adm2_norm_geog_filter$fac_type,".jpeg",sep="")
  
  jpeg(filename,width=7,height=7,units="in",bg="white",quality=1,res=300,type=c("quartz")) # jpeg basic specifications.
  
  plotgeogrg1 <- ggplot(adm2_norm_geog_filter,aes(x=value,y=trav_cat, fill=trav_cat),trim=TRUE) +
    scale_fill_manual(values=colors) +
    ggtitle(paste("Average travel times to ",adm2_norm_geog_filter$fac_type,"\nDensity plot of local government averages, per category",sep=""),paste("Median LGU population: 26,623")) +
    # ylab("Average travel time to nearest facility",vjust=-3) +
    xlab("Average % of LGU population") +
    geom_density_ridges(
      rel_min_height=0.01,scale=1,
      jittered_points = TRUE,
      position=position_points_jitter(width=0, height=0.01,adjust_vlines=TRUE),point_shape="|",point_size=1.5,point_alpha=0.5, alpha=0.5) +
    theme_ridges() +
    theme(legend.position="none",axis.text.y = element_text(angle=45, hjust=1),axis.title.y=element_blank()) +
    stat_density_ridges(quantile_lines = TRUE,quantiles=c(0.25,0.5,0.75),alpha=0.7,scale=1) +
    scale_x_continuous(limits=c(0,1),labels = scales::percent) +
    facet_wrap(~geog_label,labeller=labeller(geog_label=label_wrap_gen(width=10)))
  
  print(plotgeogrg1)
  
  df_ridge_nowalk_list[[i]] = plotgeogrg1
  
  dev.off()
}

## export joint national charts

nat_grid_items <- c(1:5,7)

jpeg(width=6.5,height=8.8,units="in",bg="white",quality=1,res=300,type=c("quartz")) # jpeg basic specifications.
do.call(grid.arrange,c(nat_grid[c(2,3)],nrow=2));
ggplot();
dev.off()

