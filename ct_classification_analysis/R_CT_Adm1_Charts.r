# R data analysis steps


## libraries

library.path <- .libPaths()
print(library.path)

library("ggplot2", lib.loc = library.path)
library("scales", lib.loc = library.path)
library("stringr", lib.loc = library.path)
library("extrafont", lib.loc = library.path)
library("dplyr", lib.loc = library.path)
library("reshape2", lib.loc = library.path)
library("forcats", lib.loc = library.path)
library("quantmod", lib.loc = library.path)
library("directlabels", lib.loc = library.path)
library("grid", lib.loc = library.path)
library("gridExtra", lib.loc = library.path)

## batch scripting setup

setwd(".") # setwd to read in file
args <- commandArgs(TRUE)
adm1_input <- read.csv(args[1], header=TRUE)
season <- str_extract(args[1],"[^_]*")
type <- str_extract(args[1],"(?<=_).*(?=_)")
print(season)
print(type)
# charts_folder <- args[2]

### exporting

export_directory=paste("../Charts/",season,"/",type,sep="")
print(export_directory)
dir.create(file.path(export_directory),showWarnings=FALSE)

## revise data

adm1_input_slim <- subset(adm1_input, select = c("adm_name","adm_code","trav_value","trav_cat","adm_pop","cat_pop","pc_pop")) # create working subset
adm1_input_slim$trav_cat <- factor(adm1_input_slim$trav_cat, levels = c("0 to 30 minutes","30 minutes to 1 hour","1 to 2 hours","2 to 4 hours","4 to 8 hours","8 to 16 hours","16 to 32 hours","> 32 hours"))  #order trav_cat in the right way
adm1_input_slim$cat_pop <- prettyNum(round(adm1_input_slim$cat_pop,digits=0),big.mark=",",scientific=FALSE) # make population round with commas
adm1_input_slim$pc_pop <- adm1_input_slim$pc_pop # make population round with commas
adm1_input_slim$pc_pop <- round(adm1_input_slim$pc_pop,digits=4) # make population round with commas
adm1_input_slim$trav_value <- as.factor(adm1_input_slim$trav_value)
adm1_order <- adm1_input_slim[order(adm1_input_slim$adm_code,adm1_input_slim$trav_cat),]

## define color palette variablesprov_list=list()

cols <- c("1" = 'darkgreen', "2" = '#2ab72e', "3" = 'lightgreen', "4" = '#e3eb96', "5" = '#f4f007', "6" = '#FECC42', "7" = '#f96a34', "8" = "red")


## charts setup

# setwd(export_directory) # setwd to exports charts to

## loop lgu charts

prov_list=list()

for (i in unique(adm1_order$adm_code)) {

  adm1_filter <- filter(adm1_order, adm_code == i)

  title=paste("Province ",adm1_filter$adm_name,sep="")
  subtitle=paste("Population",prettyNum(adm1_filter$adm_pop,big.mark = ",",scientific=FALSE,digits=0))

  plot <- ggplot(adm1_filter, aes(x = trav_cat, y = pc_pop, fill = trav_value)) +
    geom_text(aes(label=paste((pc_pop*100),"%\n",cat_pop," persons",sep="")),hjust=-0.1,size=2.5) +
    ggtitle(title,subtitle) +
    theme(axis.text.y = element_text(angle=45, hjust=1),axis.title.y=element_blank(),panel.grid.major.x = element_line(color="#ffffff", size=0.15,lineend="round"),panel.grid.major.y = element_blank(),legend.position="none",plot.title=element_text(size=12,hjust=0.975,margin=margin(b=0)),plot.subtitle=element_text(size=8,hjust=0.975,margin=margin(b=-22))) +
    scale_y_continuous(limits=c(0,1),labels = scales::percent) +
    ylab("% of provincial population") +
    # xlab("Travel time to nearest facility") +
    stat_summary(fun.y="identity",geom="bar") +
    scale_fill_manual(values= cols) +
    coord_flip()

  filename=paste("./",export_directory,"/","Province ",adm1_filter$adm_name," - ",season,"_",type,".pdf",sep="")

  prov_list[[i]] = plot

}

print("done with plotting")


## LGU print loop

for (i in unique(adm1_order$adm_code)) { # Another for loop, this time to save out the bar charts in prov_list as PDFs
    adm1_filter <- filter(adm1_order, adm_code == i)
    filename=paste("Province ",adm1_filter$adm_name," - ",season,"_",type,".jpeg",sep="") # Make the file name for each PDF. The paste makes the name a variable of the admin, so each chart is named by LGU and code

    jpeg(filename,width=3.5,height=4,units="in",bg="white",quality=1,res=300,type=c("quartz")) # jpeg basic specifications. Modify the width and height here.

    print(prov_list[[i]])

    dev.off()
}

print("done with printing")
