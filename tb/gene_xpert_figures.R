# ----------------------------------------------
# Caitlin O'Brien-Carelli
#
# 4/25/2019
# Maps and graphs of the GeneXpert data 
# ----------------------------------------------

# --------------------
# Set up R
rm(list=ls())
library(data.table)
library(ggplot2)
library(stringr) 
library(plyr)
library(RColorBrewer)
library(readxl) # this library loads the data 
library(stringi) # this creates a data from the file name
library(Hmisc)
library(tools)
library(raster)
library(maptools)
# --------------------

#------------------------------------------------
# to code in the same code, we need to set file pathways for each user
# change the username to your username to code
# for example: user = 'copio'

user = 'ccarelli'

# -----------------------------------------------
# place all the tb files in a single folder in order to import the folder contents

# change to the folder on your computer where all of the TB data are saved
if (user=='ccarelli') inDir = "C:/Users/ccarelli/Documents/tb_outputs/"

# create a folder for outputs, including figures and cleaned data sets as RDS files
if (user=='ccarelli') outDir = "C:/Users/ccarelli/Documents/tb_outputs/"

# set working directory to the location of your shape file for maps
setwd('J:/Project/Evaluation/GF/mapping/uga/')

#-----------------------------------
# import the data 

dt = readRDS(paste0(outDir, 'clean_genexpert_data.rds'))


#----------------------------------------------------------------------
# aesthetic properties for maps and graphs
# color palettes

bar_colors = c('GeneXpert Sites'='#9ecae1', 'Reported'='#fc9272')
alt_bar_colors = c('GeneXpert Sites'='#fee090', 'Reported'='#b2abd2')
true_false = c('#bd0026', '#3182bd')
single_red = '#bd0026'
single_blue = '#a6bddb'
turq = '#80cdc1'
ratios = c('#bd0026', '#3182bd', '#74c476', '#feb24c')
sex_colors = c('#bd0026', '#3182bd', '#74c476', '#8856a7')
lav = '#bebada'

#-------------------------------------------------------------
# maps

#---------------------
# fix the districts 

# drop the words district and hospital, fix capitalization, trim blanks
dt[ , district:=gsub('District', "", district)]
dt[ , district:=gsub('Hospital', "", district)]
dt[ , district:=toTitleCase(tolower(district))]
dt[ , district:=str_trim(district, side="both")]



merge_new_dists = function(x) {
  x[district=="Bunyangabu" | district=='Bunyangabo', district:="Kabarole"]
  x[district=="Butebo", district:="Pallisa"]
  x[district=="Kagadi", district:="Kibaale"]
  x[district=="Kakumiro", district:="Kibaale"]
  x[district=="Kyotera", district:="Rakai"]
  x[district=="Namisindwa", district:="Manafwa" ]
  x[district=="Omoro", district:="Gulu"]
  x[district=="Pakwach", district:="Nebbi"]
  x[district=="Rubanda", district:= "Kabale"]
  x[district=="Rukiga", district:="Kabale"]
  x[district=="Luwero", district:="Luweero"]
  x[district=="Sembabule", district:="Ssembabule"]
  x[district=="Kabalore", district:="Kabarole"]
  x[district=="Busiisa", district:="Busia"]
  x[district=="Bundibujo", district:="Bundibugyo"]
  x[district=="Palisa", district:="Pallisa"]
  x[district=="Kaberameido", district:="Kaberamaido"]
  
}

# run the function on your data set
# there should be 113 districts - 112 plus one missing
merge_new_dists(dt)
length(unique(dt$district))

#---------------------------------------------
# calculate rates 
dist = dt[ , lapply(.SD, sum, na.rm=T), by=district, .SDcols=9:15]
dist[ ,percent_pos:=round(100*tb_positive/total_samples, 1)]
dist[ ,percent_res:=round(100*rif_resist/tb_positive, 1)]
dist[ ,percent_res_total:=round(100*rif_resist/total_samples, 1)]
dist[ ,percent_indet:=round(100*rif_indet/tb_positive, 1)]
dist[ ,percent_indet_total:=round(100*rif_indet/total_samples, 1)]
dist[ ,error_rate:=round(100*total_errors/total_samples, 1)]

#---------------------------------------------
# uganda shapefile
map = shapefile('uga_dist112_map.shp')

# use the fortify function to convert from spatialpolygonsdataframe to data.frame
coord = data.table(fortify(map, region='dist112')) 
coord[, id:=as.numeric(id)]

# check the names for the merge
map_names = data.table(map@data) 
map_names = map_names[ ,.(dist112, dist112_na)]
names = dt[ ,unique(district)]
names[!(names %in% map_names$dist112_na)]

# merge the names
setnames(map_names, 'dist112_na', 'district')
dist = merge(dist, map_names, by='district', all.x=T)
setnames(dist, 'dist112', 'id')

# merge in the map
coord = merge(dist, coord, by='id', all=T)

#---------------------------------------------



# --------------------------------------------------------------
# exploratory graphs

pdf(paste0(outDir, 'tb_sample_figures.pdf'), height=9, width=12)

#------------------------------
# reporting by facilities

# calculate facilities reporting by region 
rep = dt[ ,.(reported=sum(reported), sites=length(unique(genexpert_site))), by=region]
reporting_rate = rep[ ,.(round(100*sum(reported)/sum(sites), 1))]

# bar graph of reporting compared to total sites 
ggplot(rep, aes(x=region, y=sites, fill='GeneXpert Sites', label=sites)) +
  geom_bar(stat="identity") +
  geom_bar(aes(y=rep$reported, fill='Reported'), stat="identity") + 
  geom_text(size = 4, position=position_stack(vjust = 1.06)) +
  scale_fill_manual(name='', values=bar_colors) + theme_minimal() +
  labs(x='Region', y='Total GeneXpert Sites', subtitle=paste0('Reporting rate: ', reporting_rate, '%'), 
       title="Number of GeneXpert sites reporting by region, April 1 - 7, 2019") +
  theme(text = element_text(size=18), axis.text.x=element_text(size=12, angle=90))

# percent reporting
rep[ ,rate:=round(100*reported/sites, 1)]
rep[ ,all:=rate==100]

# percent of facilities reporting and reporting size
ggplot(rep, aes(x=region, y=rate, color=all, size=sites, label=sites)) +
  geom_point(alpha=0.5) +
  geom_text(size = 4, position=position_stack(vjust = 1.02)) +
  theme_bw() +
  ylim(80, NA) +
  scale_color_manual(values=true_false) +
  labs(title="Percent of GeneXpert reporting (%), April 1 - 7, 2019", y="Percent reporting (%)", x="Region", color="100% reported", 
       size="Number of sites", subtitle='Value label = total number of GeneXpert sites') +
  theme(text = element_text(size=14), axis.text.x=element_text(size=12, angle=90)) 

# facilities reporting by facility level 
rep_level = dt[ ,.(reported=sum(reported), sites=length(unique(genexpert_site))), by=level]

# calculate the sum of facilities that did not report
rep_level[ , no_report:=(sites-reported)]
no_reports = sum(rep_level$no_report)

# bar graph of reporting compared to total sites 
ggplot(rep_level, aes(x=level, y=sites, fill='GeneXpert Sites', label=sites)) +
  geom_bar(stat="identity") +
  geom_bar(aes(y=rep_level$reported, fill='Reported'), stat="identity") + 
  geom_text(size = 4, position=position_stack(vjust = 0.5)) +
  scale_fill_manual(name='', values=alt_bar_colors) + theme_minimal() +
  labs(x='Region', y='Total GeneXpert Sites', subtitle='Value = number of total sites*', 
       title="Number of GeneXpert sites reporting by health facility level",
       caption=paste0("*", no_reports, ' facilities did not report.' )) +
  theme(text = element_text(size=18), axis.text.x=element_text(size=12))

#------------------------------
# samples submitted by children under 14
dt[ ,.(total_samples = sum(total_samples), children = sum(children_under_14)), by=region]

#------------------------------
# count of machines by region and implementer

# machines by region and implementing partner
mach = dt[ ,.(machines=sum(machines)), by=region][order(machines)]
mach_part =  dt[ ,.(machines=sum(machines)), by=impl_partner][order(machines)]

# count of genexpert machines by region 
ggplot(mach, aes(x=reorder(region, -machines), y=machines, label=machines, fill=single_red)) +
  geom_bar(stat="identity") +
  geom_text(size = 4, position=position_stack(vjust = 1.06)) +
  scale_fill_manual(name='', values=single_red) + 
  theme_minimal() +
  labs(x='Region', y='Number of GeneXpert Machines', 
       title="Number of GeneXpert machines by region") +
  theme(text = element_text(size=18), axis.text.x=element_text(size=12, angle=90)) +
  guides(fill=FALSE)

# count of genexpert machines by implementing partner
ggplot(mach_part, aes(x=reorder(impl_partner, -machines), y=machines, label=machines, fill=single_blue)) +
  geom_bar(stat="identity") +
  geom_text(size = 4, position=position_stack(vjust = 1.1)) +
  scale_fill_manual(values=single_blue) + 
  theme_minimal() +
  labs(x='Implementing Partner', y='Number of GeneXpert Machines', 
       title="Number of GeneXpert machines by implementing partner") +
  theme(text = element_text(size=18), axis.text.x=element_text(size=12, angle=90)) +
  guides(fill=FALSE)

# ------------------------------------------------------------------------------------
# rates by region 

# calculate rates 
reg = dt[ , lapply(.SD, sum, na.rm=T), by=region, .SDcols=9:15]
reg[ ,percent_pos:=round(100*tb_positive/total_samples, 1)]
reg[ ,percent_res:=round(100*rif_resist/tb_positive, 1)]
reg[ ,percent_res_total:=round(100*rif_resist/total_samples, 1)]
reg[ ,percent_indet:=round(100*rif_indet/tb_positive, 1)]
reg[ ,percent_indet_total:=round(100*rif_indet/total_samples, 1)]
reg[ ,error_rate:=round(100*total_errors/total_samples, 1)]

# ---------------------------
# count of total samples and total positive samples
reg_sub = reg[ ,.(total_samples, tb_positive) , by=region]
reg_sub = melt(reg_sub, id.vars='region')


count_labels = reg[ ,.(total_samples = sum(total_samples), tb_positive=sum(tb_positive))]
reg_sub$variable = factor(reg_sub$variable, c('total_samples', 'tb_positive'),
                          c(paste0('Total samples (n = ', count_labels$total_samples, ')'),
                            paste0('Positive for TB (n = ', count_labels$tb_positive, ')')))

ggplot(reg_sub, aes(x=reorder(region, -value), y=value, label=value, fill=variable)) +
  geom_bar(stat="identity") +
  geom_text(size = 4, position=position_stack(vjust = 0.5)) +
  facet_wrap(~variable, scales='free_y') +
  scale_fill_manual(values=sex_colors) +
  labs(x='Region', y='Count', title='Total samples tested and TB positive samples by region') +
  theme_bw() +
  theme(text = element_text(size=18), axis.text.x=element_text(size=12, angle=90)) +
  guides(fill=FALSE)

#---------------------------------------------------------------
# tests performed by implementer

part = dt[ , lapply(.SD, sum, na.rm=T), by=impl_partner, .SDcols=9:15]
part[ ,percent_pos:=round(100*tb_positive/total_samples, 1)]
part[ ,percent_res:=round(100*rif_resist/tb_positive, 1)]
part[ ,percent_res_total:=round(100*rif_resist/total_samples, 1)]
part[ ,percent_indet:=round(100*rif_indet/tb_positive, 1)]
part[ ,percent_indet_total:=round(100*rif_indet/total_samples, 1)]
part[ ,error_rate:=round(100*total_errors/total_samples, 1)]

# count of total samples and total positive samples by implementer
part_sub = part[ ,.(total_samples, tb_positive) , by=impl_partner]
part_sub = melt(part_sub, id.vars='impl_partner')


count_labels2 = part[ ,.(total_samples = sum(total_samples), tb_positive=sum(tb_positive))]
part_sub$variable = factor(part_sub$variable, c('total_samples', 'tb_positive'),
                           c(paste0('Total samples (n = ', count_labels$total_samples, ')'),
                             paste0('Positive for TB (n = ', count_labels$tb_positive, ')')))

ggplot(part_sub, aes(x=reorder(impl_partner, -value), y=value, label=value, fill=variable)) +
  geom_bar(stat="identity") +
  geom_text(size = 4, position=position_stack(vjust = 0.5)) +
  facet_wrap(~variable, scales='free_y') +
  scale_fill_manual(values=c('#7fbc41', '#de77ae')) +
  labs(x='Implementing partner', y='Count', title='Total samples tested and TB positive samples by implementing partner') +
  theme_bw() +
  theme(text = element_text(size=18), axis.text.x=element_text(size=12, angle=90)) +
  guides(fill=FALSE)

#---------------------------------------------------------------
# return to regional graphs 

# ---------------------------
#  percent TB positive
ggplot(reg, aes(x=reorder(region, -percent_pos), y=percent_pos, label=percent_pos, fill=turq)) +
  geom_bar(stat="identity") +
  geom_text(size = 4, position=position_stack(vjust = 0.5)) +
  scale_fill_manual(values=turq) + 
  theme_minimal() +
  labs(x='Region', y='Percent positive (%)', 
       title="Percentage of total samples that were positive for TB, April 1 - 7, 2019") +
  theme(text = element_text(size=18), axis.text.x=element_text(size=12, angle=90)) +
  guides(fill=FALSE)

# comparison of percentages within total samples
compare = reg[ ,.(error_rate, percent_pos, percent_res_total, percent_indet_total), by=region]
compare = melt(compare, id.vars='region')

compare$variable = factor(compare$variable, c('error_rate', 'percent_pos', 'percent_indet_total',
                                              'percent_res_total'),
                          c('Errors', 'TB positive', 'Rifampicin indeterminate', 
                            'Rifampicin resistant')) 

# percent TB positive, rifampicin indeterminate, rifampicin resistant
ggplot(compare, aes(x=region, y=value, fill=variable)) +
  geom_bar(position ="dodge", stat="identity") +
  theme_minimal() +
  scale_fill_manual(values=ratios) +
  labs(x='Region', y='Percent (%)', 
       title="Percentage of total samples", 
       fill='') +
  theme(text = element_text(size=18), axis.text.x=element_text(size=12, angle=90)) 

# rifampicin indeterminate, rifampicin resistant
ggplot(compare[variable!='TB positive'], aes(x=region, y=value, fill=variable)) +
  geom_bar(position ="dodge", stat="identity") +
  theme_minimal() +
  scale_fill_manual(values=rev(brewer.pal(3, 'YlOrRd'))) +
  labs(x='Region', y='Percent (%)', 
       title="Percentage of total samples", 
       fill='') +
  theme(text = element_text(size=18), axis.text.x=element_text(size=12, angle=90)) 

#------------------------------------------------------------------------------------
# maps 

# total samples
ggplot(coord, aes(x=long, y=lat, group=group, fill=total_samples)) + 
  geom_polygon() + 
  geom_path(size=0.01, color="#636363") + 
  scale_fill_gradientn(colors=brewer.pal(9, 'Greens')) + 
  theme_void() + 
  labs(title="Total samples by district", subtitle="April 1 - 7, 2019",
       fill="Total samples") +
  theme(plot.title=element_text(vjust=-4), plot.subtitle=element_text(vjust=-4), 
        plot.caption=element_text(vjust=6)) + coord_fixed()

# retreatments 
ggplot(coord, aes(x=long, y=lat, group=group, fill=retreatments)) + 
  geom_polygon() + 
  geom_path(size=0.01, color="#636363") + 
  scale_fill_gradientn(colors=brewer.pal(9, 'Purples')) + 
  theme_void() + 
  labs(title="Total retreatments by district", subtitle="April 1 - 7, 2019",
       fill="Samples from retreatments") +
  theme(plot.title=element_text(vjust=-4), plot.subtitle=element_text(vjust=-4), 
        plot.caption=element_text(vjust=6)) + coord_fixed()

# tb positive samples 
ggplot(coord, aes(x=long, y=lat, group=group, fill=tb_positive)) + 
  geom_polygon() + 
  geom_path(size=0.01, color="#636363") + 
  scale_fill_gradientn(colors=brewer.pal(9, 'Blues')) + 
  theme_void() + 
  labs(title="TB positive samples by district", subtitle="April 1 - 7, 2019",
       fill="TB positive (count)") +
  theme(plot.title=element_text(vjust=-4), plot.subtitle=element_text(vjust=-4), 
        plot.caption=element_text(vjust=6)) + coord_fixed()

# rifampicin resistant 
ggplot(coord, aes(x=long, y=lat, group=group, fill=rif_resist)) + 
  geom_polygon() + 
  geom_path(size=0.01, color="#636363") + 
  scale_fill_gradientn(colors=brewer.pal(9, 'Reds'), breaks = c(0, 1)) + 
  theme_void() + 
  labs(title="Rifampicin resistant samples by district", subtitle="Two districts with one RR sample each; April 1 - 7, 2019",
       fill=" ") +
  theme(plot.title=element_text(vjust=-4), plot.subtitle=element_text(vjust=-4), 
        plot.caption=element_text(vjust=6)) + coord_fixed()


# -------------------------------------
# percentages of TB positive 

pos = reg[ ,.(tb_positive, rif_resist, rif_indet), by=region]

# create totals for labels 
labels = pos[ ,lapply(.SD, sum), .SDcols=2:4]

# calculate ratios, label, and visualize
pos[ , res_ratio:=100*rif_resist/tb_positive]
pos[ , ind_ratio:=100*rif_indet/tb_positive]
pos = pos[ ,.(res_ratio, ind_ratio), by=region]
pos = melt(pos, id.vars='region')
pos[variable=='ind_ratio', variable:=paste0('Rifampicin indeterminate (n = ', labels$rif_indet, ')')]
pos[variable=='res_ratio', variable:=paste0('Rifampicin resistant (n = ', labels$rif_resist, ')')]


# rifampicin indeterminate, rifampicin resistant
ggplot(pos, aes(x=region, y=value, fill=variable)) +
  geom_bar(position ="dodge", stat="identity") +
  theme_minimal() +
  scale_fill_manual(values=c('#7fbc41', '#fdb863')) +
  labs(x='Region', y='Percent (%)', 
       title="Percentage of TB positive samples", 
       fill='', subtitle=paste0('n = ', labels$tb_positive)) +
  theme(text = element_text(size=18), axis.text.x=element_text(size=12, angle=90)) 


# -------------------------------------
# maps of percentages 

idVars = c('id', 'lat', 'long', 'order', 'hole', 'piece', 'group')
new = coord[ ,.(percent_pos, percent_res), by=idVars]
new = melt(new, id.vars=idVars)

new$variable = factor(new$variable, c('percent_pos', 'percent_res'),
                      c('Percentage of tests that were TB positive',
                        'Percentage of TB positive tests that were RR'))

# rates by district
ggplot(new, aes(x=long, y=lat, group=group, fill=value)) + 
  geom_polygon() + 
  geom_path(size=0.01, color="#636363") + 
  facet_wrap(~variable, scales='free_y') +
  scale_fill_gradientn(colors=brewer.pal(11, 'PuBuGn')) + 
  theme_void() + 
  labs(fill="%") +   theme(text = element_text(size=18))

# ----------------------------------------------------------
# implementing partners  

# total samples by implementing partner
total_part = sum(part$total_samples)

ggplot(part, aes(x=reorder(impl_partner, -total_samples), y=total_samples, fill='Total samples')) +
  geom_bar(stat="identity") +
  theme_minimal() +
  labs(x='Implementing Partner', y='Total Samples', title='Total samples by implementing partner',
       subtitle=paste0('Total samples: ', total_part), 
       fill=" ") +
  theme(text = element_text(size=18), axis.text.x=element_text(size=12, angle=90))

# ---------------------------
#  percent TB positive

# percent tb positive by implementing partner
ggplot(part, aes(x=reorder(impl_partner, -percent_pos), y=percent_pos, label=percent_pos, fill=lav)) +
  geom_bar(stat="identity") +
  geom_text(size = 4, position=position_stack(vjust = 0.5)) +
  scale_fill_manual(values=lav) + 
  theme_minimal() +
  labs(x='Implementing partner', y='Percent positive (%)', 
       title="Percentage of total samples that were positive for TB") +
  theme(text = element_text(size=18), axis.text.x=element_text(size=12, angle=90)) +
  guides(fill=FALSE)

# comparison of percentages within total samples
compare_part = part[ ,.(error_rate, percent_pos, percent_res_total, percent_indet_total), by=impl_partner]
compare_part  = melt(compare_part , id.vars='impl_partner')

compare_part$variable = factor(compare_part$variable, c('error_rate', 'percent_pos', 'percent_indet_total',
                                                        'percent_res_total'),
                               c('Errors', 'TB positive', 'Rifampicin indeterminate', 
                                 'Rifampicin resistant')) 

# percent TB positive, rifampicin indeterminate, rifampicin resistant
ggplot(compare_part, aes(x=impl_partner, y=value, fill=variable)) +
  geom_bar(position ="dodge", stat="identity") +
  theme_minimal() +
  scale_fill_manual(values=ratios) +
  labs(x='Implementing Partner', y='Percent (%)', 
       title="Percentage of total samples", 
       fill='') +
  theme(text = element_text(size=18), axis.text.x=element_text(size=12, angle=90)) 
# ---------------------------


dev.off()

# ---------------------------





