rm(list=ls())

# SETUP -------------------------------------------------------------------

library(ggplot2)
library("car")
library("lubridate")
library(here)
library(tidyverse)
library(lme4)
library(reshape2)
library(stringr)
library(dplyr)
library(sf)
library(mapview)
library(leaflet)
library(ggOceanMaps)
library(geodist)

Restimates_Filenames <- dir("Data/11_Restimates_Parallel")

Restimates_split <- do.call(rbind, strsplit(Restimates_Filenames, "_"))[, 1:2]
Restimates_Files <- data.frame(cbind(Restimates_Filenames, Restimates_split))
colnames(Restimates_Files) <- c('Filename','TOPPID','SealID')
Restimates_Files$FileID <- paste(Restimates_Files$TOPPID,"_",Restimates_Files$SealID,sep="")
FileIDs <- unique(Restimates_Files$FileID)
TOPPIDs <- unique(Restimates_Files$TOPPID)

Restimates_Files$Dive_files <- str_extract(Restimates_Files$Filename, ".*Daily_Activity.csv")

Daily_Files <- dir("Data/11_Restimates_Parallel",pattern=".*Daily_Activity.csv")
Dives_Files <- dir("Data/11_Restimates_Parallel",pattern=".*Dives.csv")

Restimates_Metadata <- read_csv("Data/11_Sleep_Model_Summary.csv",na='NaN')
Restimates_Metadata <- Restimates_Metadata %>% drop_na(TOPPID)

# Issue with 288 - have a track but no Dives.csv file
for (i in 1:100) { 
  Dives <- read_csv(paste("Data/11_Restimates_Parallel/",FileIDs[i],"_Dives.csv",sep=""),na='NaN')
  Daily <- read_csv(paste("Data/11_Restimates_Parallel/",FileIDs[i],"_Daily_Activity.csv",sep=""),na='NaN')
  SealsUsed <- read_csv(paste("Data/11_Restimates_Parallel/",FileIDs[i],"_Seals_Used.csv",sep=""))
  
  
  Daily <- Daily %>% drop_na(Days_Elapsed)
  SealsUsed <- SealsUsed %>% drop_na(SEALID)
  Daily$Percent_of_Trip <- round(100*(Daily$Days_Elapsed / max(Daily$Days_Elapsed)))
  
  if (SealsUsed$Season[1] == 1 | (SealsUsed$Trip_Duration[1] < 150 & SealsUsed$Trip_Duration[1] > 50)){
    Dives$Season_Code = "PB"
    Daily$Season_Code = "PB"
    SealsUsed$Season_Code = "PB"
  }else if (SealsUsed$Season[1] == 2 | SealsUsed$Trip_Duration[1] > 150){
    Dives$Season_Code = "PM"
    Daily$Season_Code = "PM"
    SealsUsed$Season_Code = "PM"
  }else {
    Dives$Season_Code = "other"
    Daily$Season_Code = "other"
    SealsUsed$Season_Code = "other"
  }
  
  Model_good <- Restimates_Metadata$Model_Quality[Restimates_Metadata$TOPPID==SealsUsed$TOPPID[1]]
  if (i==1 & Model_good){
    # ONLY RUN FOR FIRST ANIMAL
    Dives_ALL     <- Dives
    Daily_ALL     <- Daily
    SealsUsed_ALL <- SealsUsed
  }
  if (i>1 & Model_good){
    #RUN FOR SUBSEQUENT ANIMALS
    Dives_ALL <- rbind.fill(Dives_ALL, Dives)
    Daily_ALL <- rbind.fill(Daily_ALL, Daily)
    SealsUsed_ALL <- rbind.fill(SealsUsed_ALL, SealsUsed)
  }
}

for (i in 101: length(FileIDs)-4) { # All except sleep data and Images folder
  Dives <- read_csv(paste("Data/11_Restimates_Parallel/",FileIDs[i],"_Dives.csv",sep=""),na='NaN')
  Daily <- read_csv(paste("Data/11_Restimates_Parallel/",FileIDs[i],"_Daily_Activity.csv",sep=""),na='NaN')
  SealsUsed <- read_csv(paste("Data/11_Restimates_Parallel/",FileIDs[i],"_Seals_Used.csv",sep=""))
  
  
  Daily <- Daily %>% drop_na(Days_Elapsed)
  SealsUsed <- SealsUsed %>% drop_na(SEALID)
  Daily$Percent_of_Trip <- round(100*(Daily$Days_Elapsed / max(Daily$Days_Elapsed)))
  
  if (SealsUsed$Season[1] == 1 | (SealsUsed$Trip_Duration[1] < 150 & SealsUsed$Trip_Duration[1] > 50)){
    Dives$Season_Code = "PB"
    Daily$Season_Code = "PB"
    SealsUsed$Season_Code = "PB"
  }else if (SealsUsed$Season[1] == 2 | SealsUsed$Trip_Duration[1] > 150){
    Dives$Season_Code = "PM"
    Daily$Season_Code = "PM"
    SealsUsed$Season_Code = "PM"
  }else {
    Dives$Season_Code = "other"
    Daily$Season_Code = "other"
    SealsUsed$Season_Code = "other"
  }
  
  Model_good <- Restimates_Metadata$Model_Quality[Restimates_Metadata$TOPPID==SealsUsed$TOPPID[1]]
  if (i==1 & Model_good){
    # ONLY RUN FOR FIRST ANIMAL
    Dives_ALL     <- Dives
    Daily_ALL     <- Daily
    SealsUsed_ALL <- SealsUsed
  }
  if (i>1 & Model_good){
    #RUN FOR SUBSEQUENT ANIMALS
    Dives_ALL <- rbind.fill(Dives_ALL, Dives)
    Daily_ALL <- rbind.fill(Daily_ALL, Daily)
    SealsUsed_ALL <- rbind.fill(SealsUsed_ALL, SealsUsed)
  }
}

# OMIT NANs before writing CSVs

write.csv(Dives_ALL,"Data/11_Restimates_ALL_Dives.csv",row.names = FALSE)
write.csv(Daily_ALL,"Data/11_Restimates_ALL_DailyActivity.csv",row.names = FALSE)
write.csv(SealsUsed_ALL,"Data/11_Restimates_ALL_SealsUsed.csv",row.names = FALSE)


# Read data back in ----

Dives_ALL <- read_csv("Data/11_Restimates_ALL_Dives.csv")
Daily_ALL <- read_csv("Data/11_Restimates_ALL_DailyActivity.csv")
SealsUsed_ALL <- read_csv("Data/11_Restimates_ALL_SealsUsed.csv")

# Make summary table ----

# Simplify seals used summary table
Summary_Table <- SealsUsed_ALL %>% 
  select('TOPPID','SEALID','Season_Code','Trip_Duration','Total_Transit','Total_Forage','Total_Drift','Total_Benthic','Total_Dives')

# First, group by TOPPID, SEALID, and Season_Code to see how many same-season
# deployments were done (used later in line 168).

Daily_Budgets_ALL <- Daily_ALL %>% 
  group_by(TOPPID) %>% 
  dplyr::mutate(triprecord_days = max(Days_Elapsed)) %>% 
  group_by(SEALID,Season_Code) %>% 
  dplyr::mutate(deploys_per_seal = length(unique(TOPPID)))

# Print out information on how many same-season deployments there were
MinRepeatDeploymentSeals <- unique(Daily_Budgets_ALL$SEALID[Daily_Budgets_ALL$deploys_per_seal==min(Daily_Budgets_ALL$deploys_per_seal)])
MaxRepeatDeploymentSeals <- unique(Daily_Budgets_ALL$SEALID[Daily_Budgets_ALL$deploys_per_seal==max(Daily_Budgets_ALL$deploys_per_seal)])
paste("There were as many as",max(Daily_Budgets_ALL$deploys_per_seal), 
      "same-season deployments on", length(MaxRepeatDeploymentSeals),"seals with IDs:")
print(MaxRepeatDeploymentSeals)

paste("There were as few as",min(Daily_Budgets_ALL$deploys_per_seal), 
      "same-season deployments on", length(MinRepeatDeploymentSeals),"seals with IDs:")
print(MinRepeatDeploymentSeals)

# Pivot longer to have one observation per row - condensing all metrics for daily budgets into two columns - name & h_per_day
Daily_Budgets_ALL_long <- Daily_Budgets_ALL %>% 
  filter(daily_recording > 23.9 & daily_recording < 24.1) %>% # Must have at least 23.9 out of 24 h (excludes haulouts and days at the beginning and end of recording)
  pivot_longer(c('daily_recording','daily_diving','daily_SI','daily_long_SI',
                 'daily_filtered_long_drift','daily_filtered_long_drift_long_SI',
                 'daily_unfiltered_long_drift','daily_unfiltered_long_drift_long_SI',
                 'daily_drift','dailydive_glide','dailydive_long_glide'),
               names_to = "DailyActivity_label",
               values_to = "h_per_day"
  ) %>% 
  select('TOPPID','SEALID','Season_Code','triprecord_days','deploys_per_seal', # Metadata
         'unique_Days','Days_Elapsed','Percent_of_Trip', # Time-keeping
         'DailyActivity_label','h_per_day', # Model output summary
         'Sunrise_time_of_day','Sunset_time_of_day', 
         'Lat','Long') 
  # %>% drop_na('h_per_day')

Daily_Budgets_long <- Daily_Budgets_ALL %>% 
  filter(daily_recording > 23.9 & daily_recording < 24.1) %>% # Must have at least 23.9 out of 24 h (excludes haulouts and days at the beginning and end of recording)
  pivot_longer(c('daily_recording','daily_diving','daily_long_SI',
                 'daily_filtered_long_drift_long_SI',
                 'daily_unfiltered_long_drift_long_SI',
                 'dailydive_long_glide'),
               names_to = "DailyActivity_label",
               values_to = "h_per_day"
  ) %>% 
  select('TOPPID','SEALID','Season_Code','triprecord_days','deploys_per_seal', # Metadata
         'unique_Days','Days_Elapsed','Percent_of_Trip', # Time-keeping
         'DailyActivity_label','h_per_day', # Model output summary
         'Sunrise_time_of_day','Sunset_time_of_day', 
         'Lat','Long') 
  # %>% drop_na('h_per_day')


# Save data 
write.csv(Daily_Budgets_ALL_long,"Data/11_Restimates_ALL_DailyActivity_ALL_long.csv",row.names = FALSE)
write.csv(Daily_Budgets_long,"Data/11_Restimates_ALL_DailyActivity_long.csv",row.names = FALSE)


# Group by individual, trip percent, to get 
TripPercent_Summary <- Daily_Budgets_long %>% 
  group_by(Season_Code,SEALID,Percent_of_Trip,DailyActivity_label) %>% # Group by SEALID (group )
  dplyr::summarise(mean_h_per_trippercent = mean(h_per_day),
                   sd_h_per_trippercent = sd(h_per_day))

# Group by individual, trip percent, to get 
TripPercent_Summary_eachseal <- Daily_Budgets_long %>% 
  group_by(Season_Code,SEALID,DailyActivity_label) %>% # Group by SEALID (group )
  dplyr::summarise(mean_h_per_seal = mean(h_per_day),
                   sd_h_per_seal = sd(h_per_day))

TripPercent_Summary_ALLSEALS <- Daily_Budgets_long %>% 
  group_by(Season_Code,Percent_of_Trip,DailyActivity_label) %>% # Group by SEALID (group )
  dplyr::summarise(mean_h_per_trippercent = mean(h_per_day),
                   sd_h_per_trippercent = sd(h_per_day))
 
Season_Summary <- Daily_Budgets_long %>% 
  drop_na('h_per_day') %>% 
  group_by(Season_Code,DailyActivity_label) %>% # Group by Season
  dplyr::summarise(mean_h_per_day = mean(h_per_day),
                   sd_h_per_day = sd(h_per_day),
                   N_unique_seals = length(unique(SEALID)))

Season_TripRecord_Summary <- Daily_Budgets_long %>% 
  group_by(Season_Code) %>% # Group by Season
  dplyr::summarise(mean_triprecord_days = mean(triprecord_days),
                   sd_triprecord_days = sd(triprecord_days))

dailyactivity.col = c("Diving"= "#0c2c84",
                      "Sleep Estimate" = "#41b6c4", 
                      "Extended Surface Intervals" = "#FCBE46",
                      "Recording"="#D7D7D7",
                      "Long Drifts" = "#c7e9b4", 
                      "Long Glides" = "#225ea8")

Season_Summary$DailyActivity_label <- as.factor(Season_Summary$DailyActivity_label)
TripPercent_Summary_eachseal$DailyActivity_label <- as.factor(TripPercent_Summary_eachseal$DailyActivity_label)


levels(Season_Summary$DailyActivity_label) <- c("Diving", "Sleep Estimate", "Extended Surface Intervals","Recording","Long Drifts","Long Glides")
levels(TripPercent_Summary_eachseal$DailyActivity_label) <- c("Diving", "Sleep Estimate", "Extended Surface Intervals","Recording","Long Drifts","Long Glides")


Daily_Activity_Budget_plot <- ggplot()+
  geom_hline(yintercept = 2, linetype='dashed',alpha=0.2)+
  geom_col(data=Season_Summary, aes(x = reorder(DailyActivity_label, desc(mean_h_per_day)), 
                                         y = mean_h_per_day, 
                                         fill = reorder(DailyActivity_label, desc(mean_h_per_day))),
           alpha=0.9)+
  geom_jitter(data=TripPercent_Summary_eachseal, aes(x=reorder(DailyActivity_label, desc(mean_h_per_seal)),
                                                     y=mean_h_per_seal) , alpha = 0.1)+
  geom_text(data=Season_Summary,aes(x = reorder(DailyActivity_label, desc(mean_h_per_day)), 
                                    y = mean_h_per_day+2.0, 
                                    label = paste(round(mean_h_per_day,digits=1),"±",round(sd_h_per_day,digits=1))),
            size=4, hjust=0.5)+
  #scale_fill_manual(values=dailyactivity.col)+
  scale_fill_brewer(palette="YlGnBu", direction = -1)+
  scale_color_brewer(palette="YlGnBu", direction = -1)+
  facet_grid(cols=vars(Season_Code))+
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  labs(x="Daily activity", y="Hours per day")+
  theme_classic()+
  theme(legend.position ='none')+
  scale_y_continuous(breaks = c(0,2,4,6,8,10,12,14,16,18,20,22,24),limits = c(0,25))
Daily_Activity_Budget_plot

ggsave("Figures/11_Daily_Activity_Budget_barplot.png",Daily_Activity_Budget_plot, width= 10,height = 8,units="in",dpi=300)
ggsave("Figures/11_Daily_Activity_Budget_barplot.pdf",Daily_Activity_Budget_plot, width= 10,height = 8,units="in",dpi=300)

TripPercent_Summary_plot <- TripPercent_Summary_ALLSEALS

TripPercent_Summary_plot$mean_h_per_trippercent[is.na(TripPercent_Summary_plot$mean_h_per_trippercent)] <- 0
TripPercent_Summary_plot$sd_h_per_trippercent[is.na(TripPercent_Summary_plot$sd_h_per_trippercent)] <- 0

levels(TripPercent_Summary_plot$DailyActivity_label) <- c("Recording","Diving","Long Drifts","Sleep Estimate","Extended Surface Intervals","Long Glides")

stacked_area_Daily_Activity_plot <- ggplot()+
  geom_area(data=TripPercent_Summary_plot, aes(x=Percent_of_Trip, 
                                               y=mean_h_per_trippercent, 
                                               fill=reorder(DailyActivity_label, desc(mean_h_per_trippercent))),position="identity")+
  #scale_fill_manual(values=dailyactivity.col)+
  geom_hline(yintercept = 2, linetype='dashed',alpha=0.6)+
  scale_fill_brewer(palette="YlGnBu", direction = -1)+
  theme_classic()+
  scale_y_continuous(breaks = c(0,2,4,6,8,10,12,14,16,18,20,22,24),limits = c(0,25))+
  labs(x = "Percent of Trip (%)", y = "Hours per Day")+
  facet_grid(rows=vars(Season_Code))+
  labs(x="Percent of Trip (%)", y="Hours per day")+
  theme(legend.position ='bottom')
stacked_area_Daily_Activity_plot

ggsave("Figures/11_Daily_Activity_Budget_stackedareaplot.png",stacked_area_Daily_Activity_plot, width= 10,height = 6,units="in",dpi=300)
ggsave("Figures/11_Daily_Activity_Budget_stackedareaplot.pdf",stacked_area_Daily_Activity_plot, width= 10,height = 6,units="in",dpi=300)


# Sleep Summary -----------------------------------------------------------

## * Read in Sleep Stats alone ----

NewRaw_SLEEP <- read_csv("Data/11_Restimates/10_ALL_SLEEP_NewRaw.csv")
Daily_SLEEP <- read_csv("Data/11_Restimates/10_ALL_SLEEP_Daily_Activity.csv")
Dives_SLEEP <- read_csv("Data/11_Restimates/10_ALL_SLEEP_Dives.csv")
Naps_SLEEP <- read_csv("Data/11_Restimates/10_ALL_SLEEP_Naps.csv")

num_sleepdives <- sum(Dives_SLEEP$is_sleep>0)
min(Naps_SLEEP$Start_Depth[Naps_SLEEP$Water_Code=="DEEP WATER"])
max(Naps_SLEEP$End_Depth[Naps_SLEEP$Water_Code=="DEEP WATER"])
min(Naps_SLEEP$Start_Depth[Naps_SLEEP$Water_Code=="OPEN OCEAN"])
max(Naps_SLEEP$End_Depth[Naps_SLEEP$Water_Code=="OPEN OCEAN"])

longest_oceannap_min <- max(Naps_SLEEP$Duration_s[Naps_SLEEP$Water_Code!="LAND"])/60
max_sleepdepth_m <- max(Naps_SLEEP$End_Depth[Naps_SLEEP$Water_Code!="LAND"])

paste("Their breath-holding capacity liberates a niche where they can safely sleep at depth, during short (<", 
      longest_oceannap_min , 
      "min) naps up to", max_sleepdepth_m, 
      "m below the surface (N=", num_sleepdives,"sleeping dives).")

REMs <- NewRaw_SLEEP %>% 
  filter(is_REM != 0)

meanopenoceanREMroll <- mean(abs(REMs$roll[REMs$Water_Code=="OPEN OCEAN"]))
sdopenoceanREMroll <- sd(abs(REMs$roll[REMs$Water_Code=="OPEN OCEAN"]))

meanopenoceanREMpitch <- mean(REMs$pitch[REMs$Water_Code=="OPEN OCEAN"])
sdopenoceanREMpitch <- sd(REMs$pitch[REMs$Water_Code=="OPEN OCEAN"])

paste("The seals’ three-dimensional behavior in the open ocean confirmed that they always lost postural control, were upside down, and near horizontal during REM sleep", 
      "(|roll| = ", meanopenoceanREMroll, "±", sdopenoceanREMroll, "radians;",
      "pitch= ", meanopenoceanREMpitch, "±", sdopenoceanREMpitch, "radians).")

pal <- colorFactor(c("white","white","gold","gold"), domain = c("Active Waking", 
                                                                 "Quiet Waking",
                                                                 "SWS",
                                                                 "REM"))
# Basemaps that I like:
# "Stamen.Watercolor" good for stylized animations
# NASAGIBS.ViirsEarthAtNight2012
# GeoportailFrance.orthos
NewRaw_SLEEPplot <- NewRaw_SLEEP %>% 
  #filter(Water_Code != "LAND") %>% 
  filter(Water_Code == "DEEP WATER"| Water_Code =="OPEN OCEAN" | Water_Code =="SHALLOW WATER") %>% 
  slice(floor(seq(1, nrow(.), length.out = 10000)))
leaflet1 <- leaflet(NewRaw_SLEEPplot) %>% 
  addProviderTiles(providers$Stamen.TerrainBackground) %>% 
  addCircleMarkers(
    radius = ~ifelse(Simple_Sleep_Code == "Active Waking" | Simple_Sleep_Code == "Quiet Waking", 2, 9),
    color = "darkslategray",
    stroke = TRUE,
    weight= 1,
    fillOpacity = 1
  ) %>% 
  addCircleMarkers(
    radius = ~ifelse(Simple_Sleep_Code == "Active Waking" | Simple_Sleep_Code == "Quiet Waking", 0.5, 6),
    color = ~pal(Simple_Sleep_Code),
    stroke = TRUE,
    weight= 1,
    fillOpacity = 1
  ) %>% 
  addScaleBar()
leaflet1

mapshot(leaflet1,
    url = NULL,
    file = "Figures/11_NapMap.png",
    remove_controls = c("zoomControl", "layersControl", "homeButton", #"scaleBar",
                        "drawToolbar", "easyButton"))
  
NewRaw_SLEEPsf <- st_as_sf(NewRaw_SLEEP, coords = c("Long", "Lat"),  crs = 4326)
basemap(limits = c(-140, -105, 20, 40), bathymetry = TRUE) + xlab("Lat")

#Calculates closest distance to land in kilometers
Naps_SLEEP$dist2land <- dist2land(Naps_SLEEP,cores=1,bind=FALSE)
Naps_SLEEP$dist_km <- round(Naps_SLEEP$ldist)





plotNaps <- ggplot()+
  dlkfjd

mapview(NewRaw_SLEEP, xcol = "Long", ycol = "Lat", crs = 4269, grid = FALSE)

Naps_sf <- st_as_sf(Naps_SLEEP, coords = c("Long", "Lat"),  crs = 4326)
mapview(Naps_sf, map.types = "Stamen.Watercolor") 

NewRaw_SLEEP_downsample <- NewRaw_SLEEP %>% 
  slice(floor(seq(1, nrow(.), length.out = 10000)))
NewRaw_SLEEP_downsample <- downSample(NewRaw_SLEEP,5)





# SPATIAL DATA ----

# Calculate distance traveled per seal
latsandlons<-data.frame("latitude"=NewRaw_SLEEP$Lat,"longitude"=NewRaw_SLEEP$Long)
distances<-geodist(latsandlons,sequential=TRUE) #sequential has it calculate sequential distances
distancetraveled<-sum(distances)/1000 #distance default is in m - make km






# HYPNOGRAMS SUMMARY ------------------------------------------------------

summary_30s <- read_csv(here("Data",paste("06_summary_hypnogram_30s_ALL_ANIMALS.csv",sep="")))
summary_h <- read_csv(here("Data",paste("06_summary_per_hour_stats_ALL_ANIMALS.csv",sep="")))
summary_day <- read_csv(here("Data",paste("06_summary_per_day_stats_ALL_ANIMALS.csv",sep="")))
summary_loc <- read_csv(here("Data",paste("06_summary_per_loc_stats_ALL_ANIMALS.csv",sep="")))
summary_all <- read_csv(here("Data",paste("06_summary_stage_overall_ALL_ANIMALS.csv",sep="")))
#summary_onlyfulldays <- read_csv(here("Data",paste("06_summary_full_days_only_ALL_ANIMALS.csv",sep=""))) 

# Summarize for each location for each animal

sleep_summary_loc <- summary_loc %>% 
  mutate(h=(as.numeric(count))/3600) %>% # Change from # 30s epochs to hours
  pivot_wider(names_from=Simple.Sleep.Code,
              values_from=c(h,count,Percentage))

sleep_summary_loc$h_scored <-
  sleep_summary_loc$`h_Active Waking` +
  sleep_summary_loc$`h_Quiet Waking` + 
  sleep_summary_loc$`h_Drowsiness` + 
  sleep_summary_loc$`h_SWS` +
  sleep_summary_loc$`h_REM`
sleep_summary_loc$d_scored <- sleep_summary_loc$h_scored/24
  
sleep_summary_loc$h_sleep <-
  sleep_summary_loc$`h_SWS` +
  sleep_summary_loc$`h_REM`

sleep_summary_loc$sleep_time_h_per24 <-
  24*(sleep_summary_loc$h_sleep / sleep_summary_loc$h_scored)

sleep_summary <- sleep_summary_loc %>% 
  select(Water.Code, SealID, Recording.ID, ID, sleep_time_h_per24, d_scored) %>% 
  pivot_wider(names_from = Water.Code,
              values_from = c(sleep_time_h_per24,d_scored))

sleep_summary_ID <- sleep_summary_loc %>% 
  group_by(Water.Code,ID) %>% 
  summarise(mean_sleep_time_h_per24 = mean(sleep_time_h_per24),
            sd_sleep_time_h_per24 = sd(sleep_time_h_per24),
            Water.Code = calculate_mode(Water.Code),
            ID = calculate_mode(ID)) %>% 
  pivot_wider(names_from = Water.Code,
              values_from = c(mean_sleep_time_h_per24,sd_sleep_time_h_per24))

write.csv(sleep_summary,"Data/11_Sleep_per_loc_per_seal.csv")
write.csv(sleep_summary_ID,"Data/11_Sleep_per_loc_per_ID.csv")

# Summarize across all locations for each animal

sleep_summary_overall <- summary_all %>% 
  mutate(h=(as.numeric(count))/3600) %>% # Change from # 30s epochs to hours
  pivot_wider(names_from=Simple.Sleep.Code,
              values_from=c(h,count,Percentage))

sleep_summary_overall$h_scored <-
  sleep_summary_overall$`h_Active Waking` +
  sleep_summary_overall$`h_Quiet Waking` + 
  sleep_summary_overall$`h_Drowsiness` + 
  sleep_summary_overall$`h_SWS` +
  sleep_summary_overall$`h_REM`

sleep_summary_overall$h_sleep <-
  sleep_summary_overall$`h_SWS` +
  sleep_summary_overall$`h_REM`

sleep_summary_overall$sleep_time_h_per24 <-
  24*(sleep_summary_overall$h_sleep / sleep_summary_overall$h_scored)
sleep_summary_overall$d_scored <-
  sleep_summary_overall$h_scored/24        

write.csv(sleep_summary_overall,"Data/11_Sleep_per_seal.csv")     

# PER DAY STATS ----
sleep_summary_day <- summary_day %>% 
  filter(total == 86400) %>% 
  mutate(h=(as.numeric(count))/3600) %>% # Change from # 30s epochs to hours
  pivot_wider(names_from=Simple.Sleep.Code,
              values_from=c(h,count,Percentage))


sleep_summary_day$h_scored <-
  sleep_summary_day$`h_Active Waking` +
  sleep_summary_day$`h_Quiet Waking` + 
  sleep_summary_day$`h_Drowsiness` + 
  sleep_summary_day$`h_SWS` +
  sleep_summary_day$`h_REM`

sleep_summary_day$h_sleep <-
  sleep_summary_day$`h_SWS` +
  sleep_summary_day$`h_REM`

sleep_summary_day$sleep_time_h_per24 <-
  24*(sleep_summary_day$h_sleep / sleep_summary_day$h_scored)

sleep_summary_day_extremes <- sleep_summary_day %>% 
  group_by(SealID) %>% 
  summarise(max_sleep_time_h_per24 = max(sleep_time_h_per24),
         min_sleep_time_h_per24 = min(sleep_time_h_per24),
         SealID = calculate_mode(SealID),
         ID = calculate_mode(ID)) 

write.csv(sleep_summary_day,"Data/11_Sleep_per_day.csv")
write.csv(sleep_summary_day_extremes,"Data/11_Sleep_per_day_extremes.csv")

# Sleep summary all stages ----

sleep_summary_allstages <- summary_30s %>%
  group_by(SealID,Sleep.Code) %>% 
  summarise(hours = (n()*30)/3600, 
            SealID = calculate_mode(SealID),
            ID = calculate_mode(ID)) %>% 
  pivot_wider(names_from=Sleep.Code,
              values_from=c(hours))
sleep_summary_allstages[is.na(sleep_summary_allstages)] <- 0

sleep_summary_allstages$total <-
  sleep_summary_allstages$`Unscorable` +
  sleep_summary_allstages$`Active Waking` +
  sleep_summary_allstages$`Quiet Waking` + 
  sleep_summary_allstages$`Drowsiness` + 
  sleep_summary_allstages$`HV Slow Wave Sleep` +
  sleep_summary_allstages$`LV Slow Wave Sleep` +
  sleep_summary_allstages$`Certain REM Sleep` + 
  sleep_summary_allstages$`Putative REM Sleep`

sleep_summary_allstages$h_scored <-
  #sleep_summary_allstages$`Unscorable` +
  sleep_summary_allstages$`Active Waking` +
  sleep_summary_allstages$`Quiet Waking` + 
  sleep_summary_allstages$`Drowsiness` + 
  sleep_summary_allstages$`HV Slow Wave Sleep` +
  sleep_summary_allstages$`LV Slow Wave Sleep` +
  sleep_summary_allstages$`Certain REM Sleep` + 
  sleep_summary_allstages$`Putative REM Sleep`

sleep_summary_allstages$h_sleep <-
  #sleep_summary_allstages$`Unscorable` +
  #sleep_summary_allstages$`Active Waking` +
  #sleep_summary_allstages$`Quiet Waking` + 
  #sleep_summary_allstages$`Drowsiness` + 
  sleep_summary_allstages$`HV Slow Wave Sleep` +
  sleep_summary_allstages$`LV Slow Wave Sleep` +
  sleep_summary_allstages$`Certain REM Sleep` + 
  sleep_summary_allstages$`Putative REM Sleep`

sleep_summary_allstages$sleep_time_h_per24 <-
  24*(sleep_summary_allstages$h_sleep / sleep_summary_allstages$h_scored)

write.csv(sleep_summary_allstages,"Data/11_Sleep_per_allstages.csv")


















DailyActivity_Files

# Reading the CSV (with path)
SummaryStat_Files <- dir("G:/My Drive/Dissertation Sleep/Sleep_Analysis/Data/11_Restimates")
SummaryStat_Files

# MAKE 30s HYPNOGRAM -----

calculate_mode <- function(x) {
  uniqx <- unique(x)
  uniqx[which.max(tabulate(match(x, uniqx)))]
}

hypnogram$timebins <- cut(hypnogram$R.Time, breaks='30 sec')
hypnogram_30s <- hypnogram %>% 
  group_by(timebins, SealID, Recording.ID, ID) %>% 
  dplyr::summarise(Sleep.Code = calculate_mode(Sleep.Code),
                   Simple.Sleep.Code = calculate_mode(Simple.Sleep.Code),
                   Sleep.Num = calculate_mode(Sleep.Num),
                   Simple.Sleep.Num = calculate_mode(Sleep.Num),
                   Resp.Code = calculate_mode(Resp.Code),
                   Resp.Num = calculate_mode(Resp.Num),
                   Water.Code = calculate_mode(Water.Code),
                   Water.Num = calculate_mode(Water.Num),
                   R.Time = as.POSIXct(calculate_mode(timebins)))
hypnogram_30s$Time_s_per_day = period_to_seconds(hms(format(hypnogram_30s$R.Time, format='%H:%M:%S')))
hypnogram_30s$Time = ymd_hms(paste("2000-01-01",strftime(hypnogram_30s$R.Time,format="%H:%M:%S")))
hypnogram_30s$Date = floor_date(hypnogram_30s$R.Time, unit = "day")
hypnogram_30s$Day = floor_date(hypnogram_30s$R.Time, unit = "day")-floor_date(hypnogram_30s$R.Time[1], unit = "day")

# CALCULATE SUMMARY SLEEP STATISTICS ----
stats <- hypnogram %>% 
  group_by(Date) %>% 
  mutate(obs_per_day=n()) %>% 
  group_by(Hour,Date) %>% 
  mutate(obs_per_hour=n()) %>% 
  group_by(Hour,Date,Simple.Sleep.Code) %>% 
  mutate(sleep_per_hour=n())

stats <- stats %>% 
  group_by(Date,Simple.Sleep.Code) %>%
  mutate(sleep_per_day=n())

summarised_stats <- stats %>% 
  group_by(Hour,Date,Simple.Sleep.Code) %>% 
  summarise(Percentage=mean(sleep_per_hour/obs_per_hour))

stage_per_day <- hypnogram %>% 
  group_by(Date,Simple.Sleep.Code,.drop = FALSE) %>% 
  summarise(count=n())
stage_per_hour <- hypnogram %>% 
  group_by(Hour,Date,Simple.Sleep.Code,.drop = FALSE) %>% 
  summarise(count=n())
stage_overall <- hypnogram %>% 
  group_by(Simple.Sleep.Code,.drop = FALSE) %>% 
  summarise(count=n())
stage_per_loc <- hypnogram %>% 
  group_by(Water.Code,Simple.Sleep.Code,.drop=FALSE) %>% 
  summarise(count=n())
obs_per_day <- hypnogram %>% 
  group_by(Date) %>% 
  summarise(total=n())
obs_per_hour <- hypnogram %>% 
  group_by(Hour,Date) %>% 
  summarise(total=n())
obs_per_loc <- hypnogram %>% 
  group_by(Water.Code) %>% 
  summarise(total=n())

per_hour_stats <- full_join(stage_per_hour,obs_per_hour) %>% 
  mutate(Percentage = count/total,
         SealID = SealID,
         Recording.ID = info$Recording.ID,
         ID = sub("_[^_]+$", "", info$Recording.ID))
per_day_stats <- full_join(stage_per_day,obs_per_day) %>% 
  mutate(Percentage = count/total,
         SealID = SealID,
         Recording.ID = info$Recording.ID,
         ID = sub("_[^_]+$", "", info$Recording.ID))
per_loc_stats <- full_join(stage_per_loc,obs_per_loc) %>% 
  mutate(Percentage = count/total,
         SealID = SealID,
         Recording.ID = info$Recording.ID,
         ID = sub("_[^_]+$", "", info$Recording.ID))
stage_overall <- stage_overall %>% 
  mutate(Percentage = count/nrow(hypnogram),
         SealID = SealID,
         Recording.ID = info$Recording.ID,
         ID = sub("_[^_]+$", "", info$Recording.ID))

full_days_only <- hypnogram %>%
  group_by(Date) %>%
  mutate(nObservation = n(),
         SealID = SealID,
         Recording.ID = info$Recording.ID,
         ID = sub("_[^_]+$", "", info$Recording.ID)) %>%
  filter(nObservation == 86400)

if (i==1){
  # ONLY RUN FOR FIRST ANIMAL
  summary_per_hour_stats <- per_hour_stats
  summary_per_day_stats <- per_day_stats
  summary_per_loc_stats <- per_loc_stats
  summary_stage_overall <- stage_overall
  summary_full_days_only <- full_days_only
  summary_hypnogram_30s <- hypnogram_30s
}
if (i>1){
  #RUN FOR SUBSEQUENT ANIMALS
  summary_per_hour_stats <- rbind(summary_per_hour_stats, per_hour_stats)
  summary_per_day_stats <- rbind(summary_per_day_stats, per_day_stats)
  summary_per_loc_stats <- rbind(summary_per_loc_stats, per_loc_stats)
  summary_stage_overall <- rbind(summary_stage_overall, stage_overall)
  summary_full_days_only <- rbind(summary_full_days_only, full_days_only)
  summary_hypnogram_30s <- rbind(summary_hypnogram_30s,hypnogram_30s)
}

write.csv(hypnogram,here("Data",paste(SealID,"_06_Hypnogram_",scorer,"_",hypno_freq,".csv",sep="")), row.names = FALSE)
write.csv(hypno5hz,here("Data",paste(SealID,"_06_Hypnogram_",scorer,"_",new_freq,"Hz.csv",sep="")), row.names = FALSE)
write.csv(hypnogram_30s,here("Data",paste(SealID,"_06_Hypnogram_",scorer,"_30s.csv",sep="")), row.names = FALSE)
print("PROCESSED SUCCESSFULLY")

plotA <- ggplot(data=energy_data_broad,aes(x=year,y=value, colour=energy_type)) + 
  geom_smooth(method=lm)+
  geom_line(alpha=0.5) +
  geom_point()+
  scale_color_brewer(palette="Blues")+
  # geom_jitter(size = 3, alpha = 0.01, width = 0.15) +
  # geom_boxplot(alpha = 0.7) +
  # geom_violin(scale=2)
  # scale_fill_manual(values=SleepState_colors) +
  # xlim(11,21)+
  # ylim(-250,1000) +
  # facet_wrap(Wild.v.Captive ~ Location ~ Active.v.SWS.v.REM + Activity) +
  theme_classic()+
  # labs(y= "Signal Quality by Location")
  theme(text=element_text(family="Comic Sans MS"),
        legend.position = c(0.3,0.8),
        legend.background = 0.3)
plotA

plotB <- ggplot(data=energy_data_specific,aes(x=year,y=value, colour=energy_type)) + 
  geom_smooth()+
  geom_line(alpha=0.5) +
  geom_point()+
  scale_color_brewer(palette="Blues")+
  # geom_jitter(size = 3, alpha = 0.01, width = 0.15) +
  # geom_boxplot(alpha = 0.7) +
  # geom_violin(scale=2)
  # scale_fill_manual(values=SleepState_colors) +
  # xlim(11,21)+
  # ylim(-250,1000) +
  # facet_wrap(Wild.v.Captive ~ Location ~ Active.v.SWS.v.REM + Activity) +
  theme_classic()
# labs(y= "Signal Quality by Location")
plotB