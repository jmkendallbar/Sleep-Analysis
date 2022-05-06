




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