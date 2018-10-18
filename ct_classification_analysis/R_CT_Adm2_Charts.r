# R data analysis steps


## libraries

library.path <- .libPaths()
print(library.path)

library("ggplot2", lib.loc = library.path)
library("scales", lib.loc = library.path)
library("extrafont", lib.loc = library.path)
library("dplyr", lib.loc = library.path)
library("reshape2", lib.loc = library.path)
library("forcats", lib.loc = library.path)
library("quantmod", lib.loc = library.path)
library("directlabels", lib.loc = library.path)
library("grid", lib.loc = library.path)
library("gridExtra", lib.loc = library.path)
# loadfonts()

## batch scripting setup

setwd(".") # setwd to read in file
args <- commandArgs(TRUE)
lgu_input <- read.csv(args[1], header=TRUE)
export_directory <- args[2]
type <- args[3]

## revise data

lgu_input_slim <- subset(lgu_input, select = c("adm_name","adm2_code","province","trav_value","trav_cat","adm_pop","cat_pop","pc_pop")) # create working subset
lgu_input_slim$trav_cat <- factor(lgu_input_slim$trav_cat, levels = c("0 to 30 minutes","30 minutes to 1 hour","1 to 2 hours","2 to 4 hours","4 to 8 hours","8 to 16 hours","16 to 32 hours","> 32 hours"))  #order trav_cat in the right way
lgu_input_slim$cat_pop <- prettyNum(round(lgu_input_slim$cat_pop,digits=0),big.mark=",",scientific=FALSE) # make population round with commas
lgu_input_slim$pc_pop <- lgu_input_slim$pc_pop # make population round with commas
lgu_input_slim$pc_pop <- round(lgu_input_slim$pc_pop,digits=4) # make population round with commas
lgu_input_slim$trav_value <- as.factor(lgu_input_slim$trav_value)
lgu_order <- lgu_input_slim[order(lgu_input_slim$adm2_code,lgu_input_slim$trav_cat),]

## define color palette variableslgu_list=list()

cols <- c("1" = 'darkgreen', "2" = '#2ab72e', "3" = 'lightgreen', "4" = '#e3eb96', "5" = '#f4f007', "6" = '#FECC42', "7" = '#f96a34', "8" = "red")


## charts setup

setwd(export_directory) # setwd to exports charts to

## loop lgu charts

lgu_list=list()

for (i in unique(lgu_order$adm2_code)) {

  lgu_filter <- filter(lgu_order, adm2_code == i)

  plot <- ggplot(lgu_filter, aes(x = trav_cat, y = pc_pop, fill = trav_value)) +
    geom_text(aes(label=paste((pc_pop*100),"%\n",cat_pop," persons",sep="")),hjust=-0.1,size=2.5) +
    # ggtitle(lgu_filter$ADM_NAME) +
    theme(axis.text.y = element_text(angle=45, hjust=1),panel.grid.major.x = element_line(color="#ffffff", size=0.15,lineend="round"),panel.grid.major.y = element_blank(),legend.position="none") +
    scale_y_continuous(limits=c(0,1),labels = scales::percent) +
    ylab("% of LGU population") +
    xlab("Travel time to nearest facility") +
    stat_summary(fun.y="identity",geom="bar") +
    scale_fill_manual(values= cols) +
    coord_flip()

  filename=paste("./",export_directory,"/","Province ",lgu_filter$province," - ",lgu_filter$adm_name," - ",i," - ",type,".pdf",sep="")

  lgu_list[[i]] = plot

}

print("done with plots")


## LGU print loop

for (i in unique(lgu_order$adm2_code)) { # Another for loop, this time to save out the bar charts in lgu_list as PDFs
    lgu_filter <- filter(lgu_order, adm2_code == i)
    filename=paste("Province ",lgu_filter$province," - ",lgu_filter$adm_name," - ",i," - ",type,".jpeg",sep="") # Make the file name for each PDF. The paste makes the name a variable of the admin, so each chart is named by LGU and code

    jpeg(filename,width=3.5,height=4,units="in",bg="white",quality=1,res=300,type=c("quartz")) # jpeg basic specifications. Modify the width and height here.

    print(lgu_list[[i]])

    dev.off()
}
