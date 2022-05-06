# 07_Hypnograms -----------------------------------------------------------

# Project: Seal Sleep Study - Dissertation 
# Author: Jessica Kendall-Bar
# Objective: Create hypnograms from scored sleep data
# Date: 12/4/2021

# 1 Set up ------------------------------------------------------------------
library(ggplot2)
library(lubridate)
library(here)
library(tidyverse)
library(scales)
library(dplyr)
library(ggnewscale)
library(cowplot)
library(ggeasy)
library(conflicted)
conflict_prefer("here","here")
conflict_prefer("filter","dplyr")
conflict_prefer("mutate","dplyr")

# * 1A Save color schemes ------------------------------------------------------
sleep.col = c("Certain REM Sleep" = "#FCBE46", "Putative REM Sleep" = "#FCBE46",
              "HV Slow Wave Sleep" = "#41b6c4", "LV Slow Wave Sleep" = "#c7e9b4", "Drowsiness"="#BBA9CF",
              "Quiet Waking" = "#225ea8","Active Waking"= "#0c2c84","Unscorable"="#D7D7D7")

sleep.col2 = c("Active Waking"= "#FF7F7F", "Quiet Waking" = "#ACD7CA",
               "HV Slow Wave Sleep" = "#A3CEED", "LV Slow Wave Sleep" = "#A3CEED", 
               "Certain REM Sleep" = "#FFC000", "Putative REM Sleep" = "#FFC000")

simple.sleep.col = c("Unscorable"="#D7D7D7", "Active Waking"= "#0c2c84","Quiet Waking" = "#225ea8",
                     "Drowsiness"="#BBA9CF","REM" = "#FCBE46", "SWS" = "#41b6c4")

resp.col = c("Eupnea"= "#CDEBE6", "transition to Eupnea"="#80cdc1", 
             "Apnea"="#018571", "transition to Apnea" = "#80cdc1", "Unscorable"="#D7D7D7")
resp.col2 = c("Eupnea"= "#a6611a", "transition to Eupnea"="#dfc27d", 
              "Apnea"="#018571", "transition to Apnea" = "#80cdc1")

location.col = c("LAND"="#DBBFA2","SHALLOW WATER"="#39CCCA", "DEEP WATER"="#225ea8","OPEN OCEAN"="#0c2c84")

# 2 Load in metadata ----
SealIDs = c("test12_Wednesday",        
           "test20_SnoozySuzy",       
           "test21_DozyDaisy",
           "test23_AshyAshley",
           "test24_BerthaBeauty",
           "test25_ComaCourtney",
           "test26_DreamyDenise",
           "test30_ExhaustedEllie",
           "test31_FatiguedFiona",
           "test32_GoodnightGerty",
           "test33_HypoactiveHeidi",
           "test34_IndolentIzzy",
           "test35_JauntingJuliette")

for (i in 1:length(SealIDs)){
  print(SealIDs[i])
  SealID <- SealIDs[i] 
  
  if (file.exists(here("Data",paste(SealID,"_00_Metadata.csv",sep="")))){
    print("Metadata Exists")
  }
  
  info <- read.csv(here("Data",paste(SealID,"_00_Metadata.csv",sep=""))) 
  
  # Load in scored sleep data ----
  
  # Data scored by
  scorer = "JKB"
  
  # Read CSV made from copy/pasted Windows>Comments in LabChart; 
  
  events <- read.csv(here("Data",paste("06_Sleep_Scoring_Comments_",scorer,".csv", sep="")))
  events <- events %>% 
    filter(Seal_ID==SealID)
  
  if (nrow(events)==0){
    print("Scoring Data DOES NOT EXIST")
    next
  } else {
    print("Scoring Data Exists")
  }
  
  # Read in important metadata including time of instrument attachment/removal and time of device failure (if applicable)
  ON.ANIMAL <- mdy_hms(info$ON.ANIMAL)
  OFF.ANIMAL <- mdy_hms(info$OFF.ANIMAL)
  FAILED.END.RECORDING<-as.numeric(info$Recording.Duration_s) + mdy_hms(info$Logger.Start)
  
  # Get date time from seconds column and instrument attachment time
  events$Onset_sec <- round(events$Seconds)
  events$R.Time <- events$Onset_sec + ON.ANIMAL 
  
  # Check out the data
  unique(factor(events$Comment))
  
  # Location Scoring ----
  raw_metadata <- read.csv(here("Data","00_Raw_Scoring_Metadata.csv"))
  raw_metadata$R.Time <- mdy_hms(raw_metadata$Corrected.Date.Time)
  
  
  # Separate times related to animal location (land, shallow water, continental shelf, open ocean)
  WaterData <- raw_metadata %>% 
    filter(Seal_ID==SealID) %>% 
    filter(Comment=="Animal Enters Water"|
             Comment=="Animal Exits Water"|
             Comment=="Animal Leaves Shallow Water"|
             Comment=="Animal Returns to Shallow Water"|
             Comment=="Animal Leaves Continental Shelf Water"|
             Comment=="Animal Returns to Continental Shelf Water"|
             Comment=="Instrument ON Animal") %>% 
    select('Seconds','Comment','R.Time')
  WaterData <- WaterData[order(WaterData$Seconds),]
  
  # Calculate duration of each state using either off-animal time or device failure time.
  for (j in 1:nrow(WaterData)){
    if (j<nrow(WaterData)){
      WaterData$duration[j] <- as.double(as.duration(interval(WaterData$R.Time[j],WaterData$R.Time[j+1])))
    }else if (j==nrow(WaterData)){
      if (str_detect(info$Device.Failure,"Yes") == "TRUE"){
        print("The device was blinking and not recording upon retrieval.")
        WaterData$duration[j] <- as.double(as.duration(interval(WaterData$R.Time[j],FAILED.END.RECORDING)))
      } else{
        WaterData$duration[j] <- as.double(as.duration(interval(WaterData$R.Time[j],OFF.ANIMAL)))
        print("The device did not fail.")
      }
    }else {
      print("Error")
    }
  }
  
  # Replace comments with desired code name & value
  for (j in 1:nrow(WaterData)){
    if (WaterData$Comment[j] == "Instrument ON Animal" | 
        WaterData$Comment[j] =="Animal Exits Water"){
      WaterData$Code[j] <- "LAND"
      WaterData$Num[j] <- 0
    }else if (WaterData$Comment[j] == "Animal Enters Water"|
              WaterData$Comment[j] == "Animal Returns to Shallow Water"){
      WaterData$Code[j] <- "SHALLOW WATER"
      WaterData$Num[j] <- 1
    }else if (WaterData$Comment[j] == "Animal Leaves Shallow Water"|
              WaterData$Comment[j] == "Animal Returns to Continental Shelf Water"){
      WaterData$Code[j] <- "DEEP WATER"
      WaterData$Num[j] <- 2
    }else if (WaterData$Comment[j] == "Animal Leaves Continental Shelf Water"){
      WaterData$Code[j] <- "OPEN OCEAN"
      WaterData$Num[j] <- 3
    }else{
      print("undefined event present")
      print(resp_events$Comment[j])
    }
  }
  
  # Respiration Pattern Scoring ----
  
  # Get respiratory comments only
  resp_events <- events %>% 
    filter(Comment=="APNEA"|
             Comment=="First Breath"|
             Comment=="Last Breath"|
             Comment=="Anticipatory HR Increase"|
             Comment=="Heart Patterns Unscorable"|
             Comment=="Heart Patterns Scorable") %>% 
    select('Seconds','Comment','R.Time')
  
  # Calculate duration of each state using either off-animal time or device failure time.
  for (j in 1:nrow(resp_events)){
    if (j<nrow(resp_events)){
      resp_events$duration[j] <- as.double(as.duration(interval(resp_events$R.Time[j],resp_events$R.Time[j+1])))
    }else if (j==nrow(resp_events)){
      if (str_detect(info$Device.Failure,"Yes") == "TRUE"){
        print("The device was blinking and not recording upon retrieval.")
        resp_events$duration[j] <- as.double(as.duration(interval(resp_events$R.Time[j],FAILED.END.RECORDING)))
      } else{
        resp_events$duration[j] <- as.double(as.duration(interval(resp_events$R.Time[j],OFF.ANIMAL)))
        print("The device did not fail.")
      }
    }else {
      print("Error")
    }
  }
  
  # Replace comments with desired code name & value
  for (j in 1:nrow(resp_events)){
    if (resp_events$Comment[j] == "APNEA"){
      resp_events$Code[j] <- "Apnea"
      resp_events$Num[j] <- -2
    }else if (resp_events$Comment[j] == "Anticipatory HR Increase"){
      resp_events$Code[j] <- "transition to Eupnea"
      resp_events$Num[j] <- 1
    }else if (resp_events$Comment[j] == "First Breath"){
      resp_events$Code[j] <- "Eupnea"
      resp_events$Num[j] <- 2
    }else if (resp_events$Comment[j] == "Last Breath"){
      resp_events$Code[j] <- "transition to Apnea"
      resp_events$Num[j] <- -1
    }else if (resp_events$Comment[j] == "Heart Patterns Scorable"){
      resp_events$Code[j] <- "Eupnea"
      resp_events$Num[j] <- 2
    }else if (resp_events$Comment[j] == "Heart Patterns Unscorable"){
      resp_events$Code[j] <- "Unscorable"
      resp_events$Num[j] <- 0
    }else{
      print("undefined event present")
      print(resp_events$Comment[j])
    }
  }
  
  # Initializing variables to store device restart information
  Restart_Start <- numeric()
  Restart_End <- numeric()
  
  # Check sequence for any deviation from Apnea > Breath > First Breath > Last Breath > Apnea etc.
  for (j in 2:nrow(resp_events)){
    if (resp_events$Code[j] == "Apnea"){
      if (resp_events$Code[j-1] != "Last Breath"){
        paste("Missing 'Breath' end bradycardia comment, check timestamp",resp_events$R.Time[j])
      }
    }else if (resp_events$Code[j] == "transition to Eupnea"){
      if (resp_events$Code[j-1] != "Apnea"){
        paste("Missing 'Apnea' start bradycardia comment, check timestamp",resp_events$R.Time[j])
      }
    }else if (resp_events$Code[j] == "Eupnea"){
      if (resp_events$Code[j-1] != "transition to Eupnea"){
        paste("Missing 'Breath' end bradycardia comment, check timestamp",resp_events$R.Time[j])
      }
    }else if (resp_events$Code[j] == "transition to Apnea"){
      if (resp_events$Code[j-1] != "Eupnea"){
        paste("Missing 'Last Breath' end breathing comment, check timestamp",resp_events$R.Time[j])
      }
    }else if (resp_events$Code[j] == "Unscorable"){
      print("Restart from")
      print(resp_events$R.Time[j])
      print("to")
      print(resp_events$R.Time[j+1])
      Restart_Start[j] <- resp_events$R.Time[j]
      Restart_End[j+1] <- resp_events$R.Time[j+1]
    }else{
      print("undefined event present")
    }
  }
  Restart_Start <- Restart_Start[!is.na(Restart_Start)]
  Restart_End <- Restart_End[!is.na(Restart_End)]
  
  Restarts <- data.frame(Restart_Start,Restart_End)
  colnames(Restarts) <- c('Restart_Start','Restart_End')
  
  # Sleep Pattern Scoring ----
  
  sleep_events <- events %>% 
    filter(Comment == 'Instrument ON Animal'|
             Comment == 'Instrument OFF Animal'|
             Comment == 'MVMT (from calm)'|
             Comment == 'JOLT (from sleep)'|
             Comment == 'CALM (from motion)'|
             Comment == 'WAKE (from sleep)'|
             Comment == 'SWS1'|
             Comment == 'SWS2'|
             Comment == 'LS (light sleep)'|
             Comment == 'REM1'|
             Comment == 'REM2'|
             Comment == 'Sleep State Unscorable') %>% 
    select('Seconds','Comment','R.Time')
  
  # Calculate duration of each state using either off-animal time or device failure time.
  for (j in 1:nrow(sleep_events)){
    if (j<nrow(sleep_events)){
      sleep_events$duration[j] <- as.double(as.duration(interval(sleep_events$R.Time[j],sleep_events$R.Time[j+1])))
    }else if (j==nrow(sleep_events)){
      if (str_detect(info$Device.Failure,"Yes") == "TRUE"){
        print("The device was blinking and not recording upon retrieval.")
        sleep_events$duration[j] <- as.double(as.duration(interval(sleep_events$R.Time[j],FAILED.END.RECORDING)))
        last_record = FAILED.END.RECORDING
      } else{
        sleep_events$duration[j] <- as.double(as.duration(interval(sleep_events$R.Time[j],OFF.ANIMAL)))
        print("The device did not fail.")
        last_record = OFF.ANIMAL
      }
    }else {
      print("Error")
    }
  }
  
  unique(sleep_events$Comment)
  
  # Replace comments with desired code name & value
  for (j in 1:nrow(sleep_events)){
    if (sleep_events$Comment[j] == "MVMT (from calm)" || 
        sleep_events$Comment[j] == "JOLT (from sleep)"){
      sleep_events$Code[j] <- "Active Waking"
      sleep_events$Num[j] <- 1
    }else if (sleep_events$Comment[j] == "CALM (from motion)" || 
              sleep_events$Comment[j] == "WAKE (from sleep)" || 
              sleep_events$Comment[j] == "Instrument ON Animal"){
      sleep_events$Code[j] <- "Quiet Waking"
      sleep_events$Num[j] <- 2
    }else if (sleep_events$Comment[j] == "SWS1"){
      sleep_events$Code[j] <- "LV Slow Wave Sleep"
      sleep_events$Num[j] <- 4
    }else if (sleep_events$Comment[j] == "SWS2"){
      sleep_events$Code[j] <- "HV Slow Wave Sleep"
      sleep_events$Num[j] <- 5
    }else if (sleep_events$Comment[j] == "LS (light sleep)"){
      sleep_events$Code[j] <- "Drowsiness"
      sleep_events$Num[j] <- 3
    }else if (sleep_events$Comment[j] == "REM2"){
      sleep_events$Code[j] <- "Certain REM Sleep"
      sleep_events$Num[j] <- 7
    }else if (sleep_events$Comment[j] == "REM1"){
      sleep_events$Code[j] <- "Putative REM Sleep"
      sleep_events$Num[j] <- 6
    }else if (sleep_events$Comment[j] == "Sleep State Unscorable"){
      sleep_events$Code[j] <- "Unscorable"
      sleep_events$Num[j] <- 0
    }else{
      print("undefined event present")
      print(sleep_events$Comment[j])
    }
  }
  
  # Creating hypnograms ----
  
  # 1Hz histogram first:
  hypno_freq = "1Hz"
  
  # Add respiratory patterns
  respno_1Hz <- data.frame(rep(resp_events$Code, resp_events$duration)) 
  respno_1Hz$New <- rep(resp_events$Num, resp_events$duration)
  respno_1Hz$Seconds <- resp_events$Seconds[1]+0:(nrow(respno_1Hz)-1) #add column for seconds elapsed
  respno_1Hz$R.Time <- round_date(resp_events$R.Time[1]+0:(nrow(respno_1Hz)-1),unit="seconds") #add column for R.Time
  colnames(respno_1Hz) <- c("Resp.Code","Resp.Num", "Seconds","Time")
  
  sleepno_1Hz <- data.frame(rep(sleep_events$Code, sleep_events$duration))
  sleepno_1Hz$New <- rep(sleep_events$Num, sleep_events$duration)
  sleepno_1Hz$Seconds <- sleep_events$Seconds[1]+0:(nrow(sleepno_1Hz)-1)
  sleepno_1Hz$R.Time <- round_date(sleep_events$R.Time[1]+0:(nrow(sleepno_1Hz)-1),unit="seconds")
  colnames(sleepno_1Hz) <- c("Sleep.Code","Sleep.Num","Seconds","Time")
  
  waterno_1Hz <- data.frame(rep(WaterData$Code, WaterData$duration))
  waterno_1Hz$New <- rep(WaterData$Num, WaterData$duration)
  waterno_1Hz$Seconds <- 0:(nrow(waterno_1Hz)-1)
  waterno_1Hz$R.Time <- round_date(WaterData$R.Time[1]+0:(nrow(waterno_1Hz)-1),unit="seconds")
  colnames(waterno_1Hz) <- c("Water.Code","Water.Num","Seconds","Time")
  
  hypnogram <- full_join(sleepno_1Hz,respno_1Hz) # joins datasets by times
  hypnogram <- full_join(hypnogram,waterno_1Hz, by="Time") # joins datasets by times
  hypnogram <- na.omit(hypnogram) # deletes end or beginning where there is no breathing or sleep scoring data
  colnames(hypnogram) <- c("Sleep.Code","Sleep.Num","Seconds","R.Time",
                           "Resp.Code","Resp.Num", 
                           "Water.Code","Water.Num","Water.sec")
  
  print("Hypnogram generated")
  
  hypnogram$Date <- as_date(hypnogram$R.Time, tz='UTC') # Can also use: floor_date(R.Time, unit = "day") to get date
  hypnogram$Time <- ymd_hms(paste("2000-01-01",strftime(hypnogram$R.Time,format="%H:%M:%S", tz='UTC')))
  hypnogram$Hour = as.double(format(hypnogram$R.Time, format='%H', tz='UTC'))
  hypnogram$SealID <- SealID
  hypnogram$Recording.ID = info$Recording.ID
  hypnogram$ID = sub("_[^_]+$", "", info$Recording.ID)
  
  
  # Simplifying different types of REM/SWS
  hypnogram <- hypnogram %>% 
    mutate(Simple.Sleep.Code = replace(Sleep.Code, Sleep.Code=="Certain REM Sleep"|
                                         Sleep.Code=="Putative REM Sleep","REM")) %>% 
    mutate(Simple.Sleep.Code = replace(Simple.Sleep.Code, Simple.Sleep.Code=="HV Slow Wave Sleep"|
                                         Simple.Sleep.Code=="LV Slow Wave Sleep","SWS")) %>% 
    mutate(Simple.Sleep.Num = replace(Sleep.Num, Sleep.Code=="Certain REM Sleep", 6)) 
  
  
  hypnogram$Simple.Sleep.Code <- factor(hypnogram$Simple.Sleep.Code, 
                                        levels = c("Unscorable", "Active Waking", "Quiet Waking",
                                                   "Drowsiness","SWS","REM"))
  hypnogram$Water.Code <- factor(hypnogram$Water.Code, 
                                 levels = c("LAND", "SHALLOW WATER", "DEEP WATER",
                                            "OPEN OCEAN"))
  
  
  new_freq <-  5
  hypnogram$Time <- as.POSIXct(hypnogram$Time, "%Y-%m-%d %H:%M:%OS3", tz='UTC')
  hypno5hz <- hypnogram[rep(seq_len(nrow(hypnogram)), each = new_freq), ]
  hypno5hz$Seconds<-seq.int(nrow(hypno5hz))/new_freq
  hypno5hz$R.Time<-hypnogram$R.Time[1]+0.04+hypno5hz$Seconds # Add 0.04 to be consistent with motion data
  
  
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

  # SINGLE ANIMAL PLOTS ------------------------------------------------------------------------
  
  # Hypnogram plot
  hypno_plot <- ggplot()+
    geom_rect(data=hypnogram_30s, aes(xmin=Time,xmax=Time+30,ymin=-7,ymax=-5.5, fill=Water.Code))+
    scale_fill_manual(values=location.col)+
    new_scale_fill()+
    geom_line(data=hypnogram_30s,aes(x=Time, y=Sleep.Num), color='grey')+
    geom_point(data=hypnogram_30s, aes(x= Time, y=Sleep.Num, color=Sleep.Code))+
    geom_rect(data=hypnogram_30s, aes(xmin=Time,xmax=Time+30,ymin=-3,ymax=1, fill=Sleep.Code), 
              alpha=1, size=0)+
    theme_classic()+
    annotate('text', x = floor_date(hypnogram_30s$Time, unit = "day")-1200, y = 4, label = "Sleep", hjust=1)+
    annotate('text', x = floor_date(hypnogram_30s$Time, unit = "day")-1200, y = 1.5, label = "Wake", hjust=1)+
    annotate('text', x = floor_date(hypnogram_30s$Time, unit = "day")-1200, y = -2, label = "Sleep State", hjust=1)+
    annotate('text', x = floor_date(hypnogram_30s$Time, unit = "day")-1200, y = -4, label = "Respiration", hjust=1)+
    annotate('text', x = floor_date(hypnogram_30s$Time, unit = "day")-1200, y = -6, label = "Location", hjust=1)+
    easy_remove_y_axis()+
    scale_fill_manual(values=sleep.col)+
    scale_color_manual(values=sleep.col)+
    new_scale_fill()+
    #scale_color_manual(values=sleep.col)+
    geom_rect(data=hypnogram_30s, aes(xmin=Time,xmax=Time+30,ymin=-5,ymax=-3, fill=Resp.Code))+
    scale_fill_manual(values=resp.col)+
    geom_hline(yintercept=2.5,color='grey',linetype='dotdash')+
    scale_x_datetime(labels=date_format('%H:%M',tz='PST8PDT'),
                     breaks=date_breaks("2 hours"),
                     limits=c(min(hypnogram_30s$Time)-3600*4,max(hypnogram_30s$Time)+20))+
    labs(y = "", x="Time of Day", fill='Respiratory Patterns',
         title=paste(SealID,"Hypnogram -",info$Recording.ID,"Age",info$Age))+
    facet_grid(rows=vars(Date),scales='free_x')+
    theme(legend.position='right')
  ggsave(here("Figures",paste(SealIDs[i],"_06_Scored_Hypnogram.pdf",sep="")),hypno_plot, width= 10,height = 6,units="in",dpi=300)
  ggsave(here("Figures",paste(SealIDs[i],"_06_Scored_Hypnogram.png",sep="")),hypno_plot, width= 10,height = 6,units="in",dpi=300)
  
  # STACKED AREA CHART
  stacked_sleep_stats_area <- ggplot()+
    geom_point(data=hypnogram_30s, aes(x=Time_s_per_day/3600-0.5,
                                       y=-0.2,color=Water.Code),size=3)+
    scale_color_manual(values=location.col)+
    labs(fill='Location')+
    geom_area(data=per_hour_stats,aes(x=Hour, y=Percentage, fill=Simple.Sleep.Code))+
    scale_fill_manual(values=simple.sleep.col)+
    theme_classic()+
    scale_y_continuous(labels = scales::percent)+
    labs(x = "Hour of Day", y = "Percentage of Hour", paste(SealID,"Percent of Sleep per hour"))+
    facet_grid(rows=vars(as.Date(Date)))
  stacked_sleep_stats_area
  
  sleeptime_per_day <- ggplot()+
    geom_col(data=per_day_stats, aes(x=Simple.Sleep.Code,y=Percentage, fill=Simple.Sleep.Code))+
    scale_fill_manual(values=simple.sleep.col)+
    geom_text(data=per_day_stats, aes(x=Simple.Sleep.Code,y=Percentage+0.05, label = paste(round(Percentage*24,digits=1),"h")), size=3, hjust=0.5)+
    facet_wrap(~Date)+
    theme_classic()
  sleeptime_per_day
  
  sleeptime_per_loc <- ggplot()+
    geom_col(data=per_loc_stats, aes(x=Simple.Sleep.Code,y=Percentage, fill=Simple.Sleep.Code))+
    scale_fill_manual(values=simple.sleep.col)+
    geom_text(data=per_loc_stats, aes(x=Simple.Sleep.Code,y=Percentage+0.05, label = paste(round(Percentage*24,digits=1),"h")), size=3, hjust=0.5)+
    facet_grid(cols=vars(Water.Code))+
    theme_classic()
  sleeptime_per_loc
  
  per_day_stats$Simple.Sleep.Code <- factor(per_day_stats$Simple.Sleep.Code, 
                                            levels = c("Unscorable","Active Waking", "Quiet Waking",
                                                       "Drowsiness","SWS","REM"))
  per_loc_stats$Simple.Sleep.Code <- factor(per_loc_stats$Simple.Sleep.Code, 
                                            levels = c("Active Waking", "Quiet Waking",
                                                       "Drowsiness","SWS","REM","Unscorable"))
  per_loc_stats$Water.Code <- factor(per_loc_stats$Water.Code, 
                                     levels = c("LAND", "SHALLOW WATER", "DEEP WATER",
                                                "OPEN OCEAN"))
  
  # PROPORTION OF SLEEP STAGE across days
  sleeptime_day <- ggplot()+
    geom_bar(data=per_day_stats, aes(x=as.Date(Date), y=Percentage, 
                                     fill=Simple.Sleep.Code), position="stack", stat="identity", width=0.6)+
    scale_fill_manual(values=simple.sleep.col)+
    new_scale_fill()+
    geom_text(data=per_day_stats,aes(x=as.Date(Date)-0.35, y=Percentage, label=paste(round(100*Percentage, 1), "%", sep="")),
              size = 3, position = position_stack(vjust = 0.5),hjust=1)+
    geom_rect(data=hypnogram_30s, aes(xmin=as.Date(Date)-0.5,xmax=as.Date(Date)+0.5,
                                      ymin=-0.1,ymax=-0.05,fill=Water.Code))+
    scale_fill_manual(values=location.col)+
    scale_y_continuous(labels=scales::percent)+
    labs(x="Day", y="Percent Time", title="Sleep Summary across Days")+
    #geom_text(data=stage_overall, aes(y=Percentage+0.05, label = paste(round(Percentage*24,digits=1),"h")), size=3, hjust=0.5)+
    theme_classic()
  sleeptime_day
  
  sleeptime_loc <- ggplot()+
    geom_bar(data=per_loc_stats, aes(x=Water.Code, y=Percentage, 
                                     fill=Simple.Sleep.Code), position="stack", stat="identity", width=0.6)+
    scale_fill_manual(values=simple.sleep.col)+
    new_scale_fill()+
    geom_text(data=per_loc_stats,aes(x=Water.Code, y=Percentage, label=paste(round(100*Percentage, 1), "%", sep="")),
              size = 3, position = position_stack(vjust = 0.5),hjust=0.5)+
    geom_rect(data=hypnogram_30s, aes(xmin=Water.Code,xmax=Water.Code,
                                      ymin=-0.1,ymax=-0.05,fill=Water.Code))+
    scale_fill_manual(values=location.col)+
    scale_y_continuous(labels=scales::percent)+
    labs(x="Location", y="Percent Time", title="Sleep Summary across Locations")+
    #geom_text(data=stage_overall, aes(y=Percentage+0.05, label = paste(round(Percentage*24,digits=1),"h")), size=3, hjust=0.5)+
    theme_classic()
  sleeptime_loc
  
  overall <- hypnogram %>%
    group_by(Date, Simple.Sleep.Code)%>%
    summarise(count = n())%>%
    arrange(desc(count))%>%
    
    ggplot(aes(x=1,y = count/sum(count), fill = Simple.Sleep.Code))+
    geom_bar(position="stack",stat="identity", width=0.3, show.legend = FALSE)+
    scale_fill_manual(values=simple.sleep.col)+
    geom_text(data=stage_overall,aes(x=1.35,y=Percentage,label = paste(round(Percentage*24,digits=1),"h",sep="")),
              position = position_stack(vjust = 0.5),
              size=3.5, hjust=1)+
    labs(x="", y="% of Time", title="Total Sleep Time")+
    theme(legend.position = 'none')+
    easy_remove_x_axis()+
    scale_y_continuous(labels=scales::percent)+
    theme_classic()
  overall
  
  overall_ordered <- hypnogram %>%
    group_by(Date, Simple.Sleep.Code)%>%
    summarise(count = n())%>%
    arrange(desc(count))%>%
    
    ggplot(aes(x = reorder(Simple.Sleep.Code, desc(count)), y = count/sum(count), fill = Simple.Sleep.Code))+
    scale_fill_manual(values=simple.sleep.col)+
    geom_text(data=stage_overall, aes(x=reorder(Simple.Sleep.Code, desc(count)),y=Percentage+0.02, label = paste(round(Percentage*24,digits=1),"h")), size=4, hjust=0.5)+
    theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
    labs(x="Sleep State", y="% of Time")+
    scale_y_continuous(labels=scales::percent)+
    #facet_wrap(~Date)+
    theme_classic()+
    geom_col(show.legend = FALSE)
  overall_ordered
  
  # SLEEP BREAKDOWN SUMMARY
  top_summary <- plot_grid(nrow=1,overall_ordered,overall,sleeptime_day,labels="AUTO",rel_widths=c(1.5,1,3))
  summary <- plot_grid(nrow=2,top_summary,hypno_plot,rel_heights = c(1,2))
  
  ggsave(here("Figures",paste(SealIDs[i],"_06_sleep_time_summary_plot.pdf",sep="")),summary, width= 12,height = 10,units="in",dpi=300)
  ggsave(here("Figures",paste(SealIDs[i],"_06_sleep_time_summary_plot.png",sep="")),summary, width= 12,height = 10,units="in",dpi=300)
  
  #CIRCULAR PLOT
  circle_activity_plot <- ggplot()+
    coord_polar(theta="x", start=-0.13)+
    geom_histogram(data=full_days_only, stat="bin", aes(x=Hour, fill=Simple.Sleep.Code), binwidth=1,show.legend = FALSE)+
    scale_fill_manual(values=simple.sleep.col)+
    scale_x_continuous(breaks=0:24, expand = c(0,0))+
    labs(x = "Hour", y = "Seconds of Sleep", paste(SealID,"Sleep per hour"))+
    theme_classic()
  circle_activity_plot
  
  # FLAT PLOT
  sleep_full_days_only <- full_days_only %>% 
    filter(Simple.Sleep.Code=="SWS" | Simple.Sleep.Code=="REM" | Simple.Sleep.Code=="LS")
  flat_sleep_density_plot <- ggplot()+
    geom_density(data=sleep_full_days_only,aes(x=Hour, y=..density.., fill=Simple.Sleep.Code, color=Simple.Sleep.Code),alpha=0.8, show.legend = FALSE)+
    geom_histogram(data=sleep_full_days_only,aes(x=Hour, y=..density.., fill=Simple.Sleep.Code), position="identity", alpha=0.2, binwidth=1, show.legend = FALSE)+
    scale_color_manual(values=simple.sleep.col)+
    scale_fill_manual(values=simple.sleep.col)+
    facet_wrap(~Simple.Sleep.Code)+
    #geom_hline(yintercept = seq(0,50, by=10), color='grey', size = 0.3)+
    labs(x = "Hour", y = "Density of Observations", title = paste(SealID,"Sleep per hour"))+
    theme_classic()
  flat_sleep_density_plot
  
  # CIRCULAR PLOT
  circle_sleep_density_plot <- ggplot()+
    coord_polar(theta="x", start=-0.13)+
    geom_density(data=sleep_full_days_only,aes(x=Hour, y=..density.., fill=Simple.Sleep.Code, color=Simple.Sleep.Code),alpha=0.8, show.legend = FALSE)+
    geom_histogram(data=sleep_full_days_only,aes(x=Hour, y=..density.., fill=Simple.Sleep.Code), position="identity", alpha=0.2, binwidth=1, show.legend = FALSE)+
    scale_color_manual(values=simple.sleep.col)+
    scale_fill_manual(values=simple.sleep.col)+
    facet_wrap(~Simple.Sleep.Code)+
    #geom_hline(yintercept = seq(0,50, by=10), color='grey', size = 0.3)+
    scale_x_continuous(breaks=0:24, expand = c(0,0))+
    labs(x = "Hour", y = "Density of Observations", title = paste(SealID,"Sleep per hour"))+
    theme_classic()
  circle_sleep_density_plot
  
  sleep_summary_plot<- plot_grid(circle_activity_plot,
                                 stacked_sleep_stats_area,
                                 flat_sleep_density_plot,
                                 circle_sleep_density_plot, labels='AUTO', rel_widths = c(1,2))
  
  ggsave(here("Figures",paste(SealIDs[i],"_06_sleep_summary_plot.pdf",sep="")),sleep_summary_plot, width= 10,height = 7,units="in",dpi=300)
  ggsave(here("Figures",paste(SealIDs[i],"_06_sleep_summary_plot.png",sep="")),sleep_summary_plot, width= 10,height = 7,units="in",dpi=300)
  
  print("PLOTS CREATED AND SAVED SUCCESSFULLY")
}

summary_per_hour_stats[is.na(summary_per_hour_stats)] <- 0
summary_per_day_stats[is.na(summary_per_day_stats)] <- 0
summary_per_loc_stats[is.na(summary_per_loc_stats)] <- 0
summary_stage_overall[is.na(summary_stage_overall)] <- 0
summary_hypnogram_30s[is.na(summary_hypnogram_30s)] <- 0

write.csv(summary_hypnogram_30s,here("Data",paste("06_summary_hypnogram_30s_ALL_ANIMALS.csv",sep="")), row.names = FALSE)
write.csv(summary_per_hour_stats,here("Data",paste("06_summary_per_hour_stats_ALL_ANIMALS.csv",sep="")), row.names = FALSE)
write.csv(summary_per_day_stats,here("Data",paste("06_summary_per_day_stats_ALL_ANIMALS.csv",sep="")), row.names = FALSE)
write.csv(summary_per_loc_stats,here("Data",paste("06_summary_per_loc_stats_ALL_ANIMALS.csv",sep="")), row.names = FALSE)
write.csv(summary_stage_overall,here("Data",paste("06_summary_stage_overall_ALL_ANIMALS.csv",sep="")), row.names = FALSE)
write.csv(summary_full_days_only,here("Data",paste("06_summary_full_days_only_ALL_ANIMALS.csv",sep="")), row.names = FALSE) 


# MULTIPLE ANIMAL SLEEP PLOTS ----

#STACKED AREA CHART
stacked_sleep_stats_area <- ggplot()+
  geom_point(data=summary_hypnogram_30s, aes(x=Time_s_per_day/3600-0.5,
                                     y=-0.2,color=Water.Code),size=3)+
  scale_color_manual(values=location.col)+
  labs(fill='Location')+
  geom_area(data=summary_per_hour_stats,aes(x=Hour, y=Percentage, fill=Simple.Sleep.Code))+
  scale_fill_manual(values=simple.sleep.col)+
  theme_classic()+
  scale_y_continuous(labels = scales::percent)+
  labs(x = "Hour of Day", y = "Percentage of Hour", paste(SealID,"Percent of Sleep per hour"))+
  facet_grid(rows=vars(as.Date(Date)), scales="free_y") #,cols=vars(Recording.ID)
stacked_sleep_stats_area
ggsave(here("Figures",paste("06_stacked_summary_plot.pdf",sep="")),stacked_sleep_stats_area, width= 10,height = 20,units="in",dpi=300)
ggsave(here("Figures",paste("06_stacked_summary_plot.png",sep="")),stacked_sleep_stats_area, width= 10,height = 20,units="in",dpi=300)


sleeptime_per_day <- ggplot()+
  geom_col(data=per_day_stats, aes(x=Simple.Sleep.Code,y=Percentage, fill=Simple.Sleep.Code))+
  scale_fill_manual(values=simple.sleep.col)+
  geom_text(data=per_day_stats, aes(x=Simple.Sleep.Code,y=Percentage+0.05, label = paste(round(Percentage*24,digits=1),"h")), size=3, hjust=0.5)+
  facet_wrap(~Date)+
  theme_classic()
sleeptime_per_day

sleeptime_per_loc <- ggplot()+
  geom_col(data=summary_per_loc_stats, aes(x=Simple.Sleep.Code,y=Percentage, fill=Simple.Sleep.Code))+
  scale_fill_manual(values=simple.sleep.col)+
  geom_text(data=summary_per_loc_stats, aes(x=Simple.Sleep.Code,y=Percentage+0.05, label = paste(round(Percentage*24,digits=1),"h")), size=3, hjust=0.5)+
  facet_grid(cols=vars(Water.Code))+
  theme_classic()
sleeptime_per_loc

per_day_stats$Simple.Sleep.Code <- factor(per_day_stats$Simple.Sleep.Code, 
                                          levels = c("Unscorable","Active Waking", "Quiet Waking",
                                                     "Drowsiness","SWS","REM"))
per_loc_stats$Simple.Sleep.Code <- factor(per_loc_stats$Simple.Sleep.Code, 
                                          levels = c("Active Waking", "Quiet Waking",
                                                     "Drowsiness","SWS","REM","Unscorable"))
per_loc_stats$Water.Code <- factor(per_loc_stats$Water.Code, 
                                   levels = c("LAND", "SHALLOW WATER", "DEEP WATER",
                                              "OPEN OCEAN"))

# PROPORTION OF SLEEP STAGE across days
sleeptime_day <- ggplot()+
  geom_bar(data=summary_per_day_stats, aes(x=as.Date(Date), y=Percentage, 
                                   fill=Simple.Sleep.Code), position="stack", stat="identity", width=0.6)+
  scale_fill_manual(values=simple.sleep.col)+
  new_scale_fill()+
  geom_text(data=summary_per_day_stats,aes(x=as.Date(Date)-0.35, y=Percentage, label=paste(round(100*Percentage, 1), "%", sep="")),
            size = 3, position = position_stack(vjust = 0.5),hjust=1)+
  geom_rect(data=summary_hypnogram_30s, aes(xmin=as.Date(Date)-0.5,xmax=as.Date(Date)+0.5,
                                    ymin=-0.1,ymax=-0.05,fill=Water.Code))+
  scale_fill_manual(values=location.col)+
  scale_y_continuous(labels=scales::percent)+
  labs(x="Day", y="Percent Time", title="Sleep Summary across Days")+
  #geom_text(data=stage_overall, aes(y=Percentage+0.05, label = paste(round(Percentage*24,digits=1),"h")), size=3, hjust=0.5)+
  theme_classic()
sleeptime_day

sleeptime_loc <- ggplot()+
  geom_bar(data=summary_per_loc_stats, aes(x=Water.Code, y=Percentage, 
                                   fill=Simple.Sleep.Code), position="stack", stat="identity", width=0.6)+
  scale_fill_manual(values=simple.sleep.col)+
  new_scale_fill()+
  geom_text(data=summary_per_loc_stats,aes(x=Water.Code, y=Percentage, label=paste(round(100*Percentage, 1), "%", sep="")),
            size = 3, position = position_stack(vjust = 0.5),hjust=0.5)+
  geom_rect(data=summary_hypnogram_30s, aes(xmin=Water.Code,xmax=Water.Code,
                                    ymin=-0.1,ymax=-0.05,fill=Water.Code))+
  scale_fill_manual(values=location.col)+
  scale_y_continuous(labels=scales::percent)+
  labs(x="Location", y="Percent Time", title="Sleep Summary across Locations")+
  facet_wrap(~Recording.ID)+
  #geom_text(data=stage_overall, aes(y=Percentage+0.05, label = paste(round(Percentage*24,digits=1),"h")), size=3, hjust=0.5)+
  theme_classic()
sleeptime_loc

overall <- hypnogram %>%
  group_by(Date, Simple.Sleep.Code)%>%
  summarise(count = n())%>%
  arrange(desc(count))%>%
  
  ggplot(aes(x=1,y = count/sum(count), fill = Simple.Sleep.Code))+
  geom_bar(position="stack",stat="identity", width=0.3, show.legend = FALSE)+
  scale_fill_manual(values=simple.sleep.col)+
  geom_text(data=stage_overall,aes(x=1.35,y=Percentage,label = paste(round(Percentage*24,digits=1),"h",sep="")),
            position = position_stack(vjust = 0.5),
            size=3.5, hjust=1)+
  labs(x="", y="% of Time", title="Total Sleep Time")+
  theme(legend.position = 'none')+
  easy_remove_x_axis()+
  scale_y_continuous(labels=scales::percent)+
  theme_classic()
overall

overall_ordered <- summary_hypnogram_30s %>%
  group_by(SealID) %>% 
  mutate(total=n()) %>% 
  group_by(SealID,Date, Simple.Sleep.Code)%>%
  dplyr::summarise(Percentage = mean(n()/total))%>%
  arrange(desc(Percentage))%>%
  
  ggplot(aes(x = reorder(Simple.Sleep.Code, desc(Percentage)), y = Percentage, fill = Simple.Sleep.Code))+
  scale_fill_manual(values=simple.sleep.col)+
  geom_text(data=summary_stage_overall, aes(x=reorder(Simple.Sleep.Code, desc(Percentage)),y=Percentage+0.1, label = paste(round(Percentage*24,digits=1),"h")), size=4, hjust=0.5)+
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  labs(x="Sleep State", y="% of Time")+
  scale_y_continuous(labels=scales::percent)+
  facet_wrap(~SealID)+
  theme_classic()+
  geom_col(show.legend = FALSE)
overall_ordered

# SLEEP BREAKDOWN SUMMARY
top_summary <- plot_grid(nrow=1,overall_ordered,overall,sleeptime_day,labels="AUTO",rel_widths=c(1.5,1,3))
summary <- plot_grid(nrow=2,top_summary,hypno_plot,rel_heights = c(1,2))

ggsave(here("Figures",paste(SealID,"_06_sleep_time_summary_plot.pdf",sep="")),summary, width= 12,height = 10,units="in",dpi=300)
ggsave(here("Figures",paste(SealID,"_06_sleep_time_summary_plot.png",sep="")),summary, width= 12,height = 10,units="in",dpi=300)

#CIRCULAR PLOT
circle_activity_plot <- ggplot()+
  coord_polar(theta="x", start=-0.13)+
  geom_histogram(data=full_days_only, stat="bin", aes(x=Hour, fill=Simple.Sleep.Code), binwidth=1,show.legend = FALSE)+
  scale_fill_manual(values=simple.sleep.col)+
  scale_x_continuous(breaks=0:24, expand = c(0,0))+
  labs(x = "Hour", y = "Seconds of Sleep", paste(SealID,"Sleep per hour"))+
  theme_classic()
circle_activity_plot

# FLAT PLOT
flat_sleep_density_plot <- ggplot()+
  geom_density(data=sleep_full_days_only,aes(x=Hour, y=..density.., fill=Simple.Sleep.Code, color=Simple.Sleep.Code),alpha=0.8, show.legend = FALSE)+
  geom_histogram(data=sleep_full_days_only,aes(x=Hour, y=..density.., fill=Simple.Sleep.Code), position="identity", alpha=0.2, binwidth=1, show.legend = FALSE)+
  scale_color_manual(values=simple.sleep.col)+
  scale_fill_manual(values=simple.sleep.col)+
  facet_wrap(~Simple.Sleep.Code)+
  #geom_hline(yintercept = seq(0,50, by=10), color='grey', size = 0.3)+
  labs(x = "Hour", y = "Density of Observations", title = paste(SealID,"Sleep per hour"))+
  theme_classic()
flat_sleep_density_plot

# CIRCULAR PLOT
circle_sleep_density_plot <- ggplot()+
  coord_polar(theta="x", start=-0.13)+
  geom_density(data=sleep_full_days_only,aes(x=Hour, y=..density.., fill=Simple.Sleep.Code, color=Simple.Sleep.Code),alpha=0.8, show.legend = FALSE)+
  geom_histogram(data=sleep_full_days_only,aes(x=Hour, y=..density.., fill=Simple.Sleep.Code), position="identity", alpha=0.2, binwidth=1, show.legend = FALSE)+
  scale_color_manual(values=simple.sleep.col)+
  scale_fill_manual(values=simple.sleep.col)+
  facet_wrap(~Simple.Sleep.Code)+
  #geom_hline(yintercept = seq(0,50, by=10), color='grey', size = 0.3)+
  scale_x_continuous(breaks=0:24, expand = c(0,0))+
  labs(x = "Hour", y = "Density of Observations", title = paste(SealID,"Sleep per hour"))+
  theme_classic()
circle_sleep_density_plot

sleep_summary_plot<- plot_grid(circle_activity_plot,
                               stacked_sleep_stats_area,
                               flat_sleep_density_plot,
                               circle_sleep_density_plot, labels='AUTO', rel_widths = c(1,2))

ggsave(here("Figures",paste(SealID,"_06_sleep_summary_plot.pdf",sep="")),sleep_summary_plot, width= 10,height = 7,units="in",dpi=300)
ggsave(here("Figures",paste(SealID,"_06_sleep_summary_plot.png",sep="")),sleep_summary_plot, width= 10,height = 7,units="in",dpi=300)


#HYPNOPLOT BY DAY

hypno_plot <- ggplot()+
  geom_line(data=hypnogram, aes(x=Time,y=Sleep.Num))+
  theme_classic()
hypno_plot

# Creating hypnoplot ----
hypno_plot <- ggplot(hypnogram,
                     aes(y=Sleep.Code,x=Time))+
  geom_point()+
  facet_wrap(~Date)+
  theme_classic()
hypno_plot


# Creating Chord Diagram ----
library(stringr)
library(circlize)

edge_resp <- data.frame(as.character(resp_events$Code))

# Create edge list with start stage in column 1 and end stage in column 2
for (j in 1:nrow(resp_events)){
  edge_resp$End[j] <- resp_events$Code[j+1]
  edge_resp$Code[j] <- resp_events$Code[j]
}

edge_resp <- na.omit(edge_resp)

grid.col = c("Apnea"= "#3494A8", "transition to Eupnea" = "#FFA770", "Eupnea" = "#D46A06",
             "transition to Apnea" = "#76E0F5")

adjacencyData <- table(edge_resp$Code, edge_resp$End)
circos.par(start.degree = 0, clock.wise = FALSE)
chordDiagram(adjacencyData, 
             transparency = 0.5, 
             order = c("Apnea", "transition to Eupnea", "Eupnea", "transition to Apnea"),
             grid.col = grid.col,
             directional = 1, 
             direction.type = c("diffHeight", "arrows"),
             scale = FALSE,
             link.arr.type = "big.arrow")
circos.clear()

# New Code which separates calm from waking ----

for (j in 1:nrow(sleep_events)){
  if (sleep_events$Comment[j] == "MVMT (LV to Motion)" || sleep_events$Comment[j] == "JOLT (SWS to Motion)"){
    sleep_events$Code[j] <- "Active Waking"
  }else if (sleep_events$Comment[j] == "CALM: (Motion to LV)"){
    sleep_events$Code[j] <- "Calm"
  }else if (sleep_events$Comment[j] == "WAKE (SWS to LV)"){
    sleep_events$Code[j] <- "Waking"
  }else if (sleep_events$Comment[j] == "SWS (LV to SWS)"){
    sleep_events$Code[j] <- "Slow Wave Sleep"
  }else if (sleep_events$Comment[j] == "Intermediate N1?"){
    sleep_events$Code[j] <- "Light Sleep"
  }else if (sleep_events$Comment[j] == "REM (SWS to VLV)"){
    sleep_events$Code[j] <- "Paradoxical Sleep"
  }else{
    print("undefined event present")
  }
}

edge_sleep <- data.frame(as.character(sleep_events$Code))
# Create edge list with start stage in column 1 and end stage in column 2
for (j in 1:nrow(sleep_events)){
  edge_sleep$End[j] <- sleep_events$Code[j+1]
  edge_sleep$Code[j] <- sleep_events$Code[j]
}

edge_sleep <- na.omit(edge_sleep)

grid.col = c("Active Waking"= "#FF7F7F", "Calm" = "#ACD7CA", "Waking" = "#ACD7CA", "Light Sleep" = "#CFCDEB",
             "Slow Wave Sleep" = "#A3CEED", "Paradoxical Sleep" = "#FFC000")

arr.col = data.frame(c("Active Waking", "Calm", "Light Sleep", "Slow Wave Sleep", "Paradoxical Sleep", "Waking"), c("Calm", "Light Sleep", "Slow Wave Sleep", "Paradoxical Sleep", "Waking","Active Waking"), c("White","White","White","White","White","White"))
#c("black", "black", "black", "black", "black", "black"))

adjacencyData <- table(edge_sleep$Code, edge_sleep$End)
circos.par(start.degree = 0, clock.wise = TRUE)
chordDiagram(adjacencyData, 
             transparency = 0.5, 
             order = rev(c("Active Waking", "Calm", "Light Sleep", "Slow Wave Sleep", "Paradoxical Sleep", "Waking")),
             grid.col = grid.col,
             directional = 1, 
             direction.type = "arrows",
             link.arr.col = arr.col, 
             link.arr.length = 0.2,
             link.arr.width = 0.5,
             scale = TRUE)

# Other Chord Diagram ----

grid.col = c("Active Waking"= "#FF7F7F", "Calm" = "#ACD7CA", "Waking" = "#ACD7CA", "Light Sleep" = "#CFCDEB",
             "Slow Wave Sleep" = "#A3CEED", "Paradoxical Sleep" = "#FFC000")

adjacencyData <- table(edge_sleep$Code, edge_sleep$End)
circos.par(start.degree = 0, clock.wise = FALSE)
chordDiagram(adjacencyData, 
             transparency = 0.5, 
             order = c("Active Waking", "Calm", "Light Sleep", "Slow Wave Sleep", "Paradoxical Sleep", "Waking"),
             grid.col = grid.col,
             directional = 1, 
             direction.type = c("diffHeight", "arrows"),
             scale = TRUE,
             link.arr.type = "big.arrow")
circos.clear()