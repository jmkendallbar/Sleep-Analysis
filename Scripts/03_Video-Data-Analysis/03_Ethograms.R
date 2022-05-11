# Setup ----
library(ggplot2)
library(lubridate)
library(here)
library(tidyverse)

# Load in metadata for scored data ----

# SealIDs = c("test12_Wednesday",...       % Recording 1
#            "test20_SnoozySuzy",...       % Recording 2
#            "test21_DozyDaisy",...        % Recording 3
#            "test23_AshyAshley",...       % Recording 4
#            "test24_BerthaBeauty",...     % Recording 5
#            "test25_ComaCourtney",...     % Recording 6
#            "test26_DreamyDenise",...     % Recording 7
#            "test30_ExhaustedEllie",...   % Recording 8
#            "test31_FatiguedFiona",...    % Recording 9
#            "test32_GoodnightGerty",...   % Recording 10
#            "test33_HypoactiveHeidi",...  % Recording 11
#            "test34_IndolentIzzy")        % Recording 12

# Manually enter video scoring metadata ----

camera = "DryWebcam"
start_str = '2020-10-09_130000'
end_str = '2020-10-09_140000'
SealID <- SealIDs[5] # HERE PICK the seal you want

# Load in scored video data ----

info <- read.csv(here("Data",paste(SealID,"_00_Metadata.csv",sep=""))) 
data <- read.csv((here("Data",paste(SealID,"_",camera,"_",start_str,"_",end_str,".csv",sep=""))))
StartRowNum <- which(data$Observation.id %in% c("Time"))
events <- read.csv((here("Data",paste(SealID,"_",camera,"_",start_str,"_",end_str,".csv",sep=""))),skip=StartRowNum)
# Save start time and end time as R.Time values
start_time = as.POSIXct(strptime(start_str, "%Y-%m-%d_%H%M%S"),
                        tz="Pacific/Easter")
end_time = as.POSIXct(strptime(end_str, "%Y-%m-%d_%H%M%S"),
                      tz="Pacific/Easter")

actual_end_sec <- as.double(as.duration(interval(start_time,end_time)))
boris_end_sec <- events$Time[nrow(events)]

events$actual_sec <- events$Time * (actual_end_sec/boris_end_sec)
# Get time column
events$Onset_sec <- round(events$actual_sec)
events$R.Time <- events$Onset_sec + start_time

# See all behavioral labels
events$Behavior <- as.factor(events$Behavior)
unique(events$Behavior)


# Animal Behavior Category (State Events) ----

# Subset events data to behavioral category
behavior_events <- events %>% 
  filter(Behavioral.category=="Animal Behavior" | Behavioral.category=="",
         Status=="START") %>%
  select('Time','Behavior','R.Time')

drifting_events <- filter(behavior_events, (Behavior %in% c('driFting')) == TRUE )
behavior_events <- filter(behavior_events, (Behavior %in% c('driFting')) == FALSE )

# Setting state event duration adaptively for single event versus multiple
if (nrow(behavior_events) > 1 ){
  print("Multiple state events")
  for (i in 1:nrow(behavior_events)){
    if (i == nrow(behavior_events)){
      behavior_events$duration[i] <- as.double(as.duration(interval(behavior_events$R.Time[i],end_time)))
    }else{
      behavior_events$duration[i] <- as.double(as.duration(interval(behavior_events$R.Time[i],behavior_events$R.Time[i+1])))
    }
  }
}else if (nrow(behavior_events) == 1){
  print("Only one state event")
  behavior_events$duration[1] <- as.double(as.duration(interval(start_time,end_time)))
}else{
  print("Zero state events")
  behavior_events$Behavior[1] <- NA
  behavior_events$duration[1] <- as.double(as.duration(interval(start_time,end_time)))
  behavior_events$R.Time[1] <- start_time
  behavior_events$Time[1] <- 0
}

# Setting state event duration adaptively for single event versus multiple
if (nrow(drifting_events) > 1 ){
  print("Multiple state events")
  for (i in 1:nrow(drifting_events)){
    if (i == nrow(drifting_events)){
      drifting_events$duration[i] <- as.double(as.duration(interval(drifting_events$R.Time[i],end_time)))
    }else{
      drifting_events$duration[i] <- as.double(as.duration(interval(drifting_events$R.Time[i],drifting_events$R.Time[i+1])))
    }
  }
}else if (nrow(drifting_events) == 1){
  print("Only one state event")
  drifting_events$duration[1] <- as.double(as.duration(interval(start_time,end_time)))
}else{
  print("Zero state events")
  drifting_events[1,] <- NA
  drifting_events$Behavior[1] <- NA
  drifting_events$duration[1] <- as.double(as.duration(interval(start_time,end_time)))
  drifting_events$R.Time[1] <- start_time
  drifting_events$Time[1] <- 0
}

#Cleaning and removing events that last 0 seconds
behavior_events <- na.omit(behavior_events)
behavior_events <- behavior_events %>%
  filter(duration > 0)

# Assign codes
for (i in 1:nrow(behavior_events)){
  if (behavior_events$Behavior[i] == "galumphing"){
    behavior_events$Code[i] <- "GL"
  }else if (behavior_events$Behavior[i] == "quiet waking"){
    behavior_events$Code[i] <- "QW"
  }else if (behavior_events$Behavior[i] == "visibly breathing"){
    behavior_events$Code[i] <- "VB"
  }else if (behavior_events$Behavior[i] == "not breathing"){
    behavior_events$Code[i] <- "NB"
  }else if (behavior_events$Behavior[i] == "swimming"){
    behavior_events$Code[i] <- "SW"
  }else if (behavior_events$Behavior[i] == "invisible"){
    behavior_events$Code[i] <- "NV"
  }else{
    print("undefined event present")
  }
}

# Animal Location Category (State Events) ----
location_events <- events %>% 
  filter(Behavioral.category=="Animal Location" | Behavioral.category=="",
         Status=="START") %>% 
  select('Time','Behavior','R.Time')

# If more than one state event, then put the duration of the event 
if (nrow(location_events) >1 ){
  print("Multiple state events")
  for (i in 1:nrow(location_events)){
    if (i == nrow(location_events)){
      location_events$duration[i] <- as.double(as.duration(interval(location_events$R.Time[i],end_time)))
    }else{
      location_events$duration[i] <- as.double(as.duration(interval(location_events$R.Time[i],location_events$R.Time[i+1])))
    }
  }
}else{
  print("Only one state event")
  location_events$duration[1] <- as.double(as.duration(interval(start_time,end_time)))
}

location_events <- na.omit(location_events)
location_events <- location_events %>%
  filter(duration > 0)

# Assign codes for each breath state

for (i in 1:nrow(location_events)){
  if (location_events$Behavior[i] == "LAND"){
    location_events$Code[i] <- "L"
  }else if (location_events$Behavior[i] == "WET"){
    location_events$Code[i] <- "W"
  }else if (location_events$Behavior[i] == "SURFACE"){
    location_events$Code[i] <- "S"
  }else if (location_events$Behavior[i] == "UNDERWATER"){
    location_events$Code[i] <- "U"
  }else if (location_events$Behavior[i] == "invisible"){
    location_events$Code[i] <- "NV"
  }else{
    print("undefined event present")
  }
}


# Body Position Category (State Events) ----
position_events <- events %>% 
  filter(Behavioral.category=="Body Position" | Behavioral.category=="",
         Status=="START") %>% 
  select('Time','Behavior','R.Time')

# If more than one state event, then put the duration of the event 
if (nrow(position_events) >1 ){
  print("Multiple state events")
  for (i in 1:nrow(position_events)){
    if (i == nrow(position_events)){
      position_events$duration[i] <- as.double(as.duration(interval(position_events$R.Time[i],end_time)))
    }else{
      position_events$duration[i] <- as.double(as.duration(interval(position_events$R.Time[i],position_events$R.Time[i+1])))
    }
  }
}else{
  print("Only one state event")
  position_events$duration[1] <- as.double(as.duration(interval(start_time,end_time)))
}

position_events <- na.omit(position_events)
position_events <- position_events %>%
  filter(duration > 0)

# Assign codes for each breath state

for (i in 1:nrow(position_events)){
  if (position_events$Behavior[i] == "prone (on belly)"){
    position_events$Code[i] <- "PR"
  }else if (position_events$Behavior[i] == "supine (on back)"){
    position_events$Code[i] <- "SU"
  }else if (position_events$Behavior[i] == "left side"){
    position_events$Code[i] <- "LS"
  }else if (position_events$Behavior[i] == "right side"){
    position_events$Code[i] <- "RS"
  }else if (position_events$Behavior[i] == "vertical up"){
    position_events$Code[i] <- "VU"
  }else if (position_events$Behavior[i] == "vertical down"){
    position_events$Code[i] <- "VD"
  }else if (position_events$Behavior[i] == "invisible"){
    position_events$Code[i] <- "NV"
  }else{
    print("undefined event present")
  }
}


# Eye State Category (State Events) ----
eyeState_events <- events %>% 
  filter(Behavioral.category=="Eye State" | Behavioral.category=="",
         Status=="START") %>% 
  select('Time','Behavior','R.Time')

# If more than one state event, then put the duration of the event 
if (nrow(eyeState_events) >1 ){
  print("Multiple state events")
  for (i in 1:nrow(eyeState_events)){
    if (i == nrow(eyeState_events)){
      eyeState_events$duration[i] <- as.double(as.duration(interval(eyeState_events$R.Time[i],end_time)))
    }else{
      eyeState_events$duration[i] <- as.double(as.duration(interval(eyeState_events$R.Time[i],eyeState_events$R.Time[i+1])))
    }
  }
}else{
  print("Only one state event")
  eyeState_events$duration[1] <- as.double(as.duration(interval(start_time,end_time)))
}

eyeState_events <- na.omit(eyeState_events)
eyeState_events <- eyeState_events %>%
  filter(duration > 0)

# Assign codes for each breath state

for (i in 1:nrow(eyeState_events)){
  if (eyeState_events$Behavior[i] == "Eyes Not Visible"){
    eyeState_events$Code[i] <- "NV"
  }else if (eyeState_events$Behavior[i] == "Eyes Open"){
    eyeState_events$Code[i] <- "O"
  }else if (eyeState_events$Behavior[i] == "Eyes Closed"){
    eyeState_events$Code[i] <- "C"
  }else if (eyeState_events$Behavior[i] == "invisible"){
    eyeState_events$Code[i] <- "NV"
  }else{
    print("undefined event present")
  }
}

# Animal Interactions Category (State Events) ----
interactions_events <- events %>% 
  filter(Behavioral.category=="Interactions" | Behavioral.category=="",
         Status=="START") %>% 
  select('Time','Behavior','R.Time')

# If more than one state event, then put the duration of the event 
if (nrow(interactions_events) >1 ){
  print("Multiple state events")
  for (i in 1:nrow(interactions_events)){
    if (i == nrow(interactions_events)){
      interactions_events$duration[i] <- as.double(as.duration(interval(interactions_events$R.Time[i],end_time)))
    }else{
      interactions_events$duration[i] <- as.double(as.duration(interval(interactions_events$R.Time[i],interactions_events$R.Time[i+1])))
    }
  }
}else{
  print("Only one state event")
  interactions_events$duration[1] <- as.double(as.duration(interval(start_time,end_time)))
}

interactions_events <- na.omit(interactions_events)
interactions_events <- interactions_events %>%
  filter(duration > 0)

# Assign codes for each breath state

for (i in 1:nrow(interactions_events)){
  if (interactions_events$Behavior[i] == "ALONE"){
    interactions_events$Code[i] <- "ALONE"
  }else if (interactions_events$Behavior[i] == "Not Alone"){
    interactions_events$Code[i] <- "NotAlone"
  }else if (interactions_events$Behavior[i] == "SOCIAL"){
    interactions_events$Code[i] <- "SOCIAL"
  }else if (interactions_events$Behavior[i] == "PROCEDURE"){
    interactions_events$Code[i] <- "PROCEDURE"
  }else if (interactions_events$Behavior[i] == "invisible"){
    interactions_events$Code[i] <- "NV"
  }else{
    print("undefined event present")
  }
}



# Creating ethograms ----

# 1Hz histogram first:
etho_freq = "1Hz"

# Add Behavior patterns
behavior_1Hz <- data.frame(rep(behavior_events$Code, behavior_events$duration))
behavior_1Hz$Seconds <- as.integer(rownames(behavior_1Hz))
behavior_1Hz$R.Time <- as.integer(rownames(behavior_1Hz))+ start_time #add column for R.Time
names(behavior_1Hz)[1] <- "Behavior_State"

# Add Drifting patterns
drifting_1Hz <- data.frame(rep(drifting_events$Behavior, drifting_events$duration))
drifting_1Hz$Seconds <- as.integer(rownames(drifting_1Hz))
drifting_1Hz$R.Time <- as.integer(rownames(drifting_1Hz))+ start_time #add column for R.Time
names(drifting_1Hz)[1] <- "Drifting_State"

# Add Location patterns
location_1Hz <- data.frame(rep(location_events$Code, location_events$duration))
location_1Hz$Seconds <- as.integer(rownames(location_1Hz))
location_1Hz$R.Time <- as.integer(rownames(location_1Hz))+ start_time #add column for R.Time
names(location_1Hz)[1] <- "Location_State"

# Add Position patterns
position_1Hz <- data.frame(rep(position_events$Code, position_events$duration))
position_1Hz$Seconds <- as.integer(rownames(position_1Hz))
position_1Hz$R.Time <- as.integer(rownames(position_1Hz))+ start_time #add column for R.Time
names(position_1Hz)[1] <- "Position_State"

# Add Eye patterns
eyeState_1Hz <- data.frame(rep(eyeState_events$Code, eyeState_events$duration))
eyeState_1Hz$Seconds <- as.integer(rownames(eyeState_1Hz))
eyeState_1Hz$R.Time <- as.integer(rownames(eyeState_1Hz))+ start_time #add column for R.Time
names(eyeState_1Hz)[1] <- "Eye_State"

# Add Social patterns
interactions_1Hz <- data.frame(rep(interactions_events$Code,interactions_events$duration))
interactions_1Hz$Seconds <- as.integer(rownames(interactions_1Hz))
interactions_1Hz$R.Time <- as.integer(rownames(interactions_1Hz))+ start_time #add column for R.Time
names(interactions_1Hz)[1] <- "Interactions_State"


# Animal Behavior Category (Point Events) ----
behavior_point_events <- events %>% 
  filter(Behavioral.category=="Animal Behavior",
         Status=="POINT") %>% 
  select('Time','Behavior','R.Time')
behavior_point_events <- rename(behavior_point_events, Behavior_Point=Behavior)

# Merging Point & State Events ----

behavior_1Hz <- full_join(behavior_1Hz,
                      behavior_point_events,
                      by="R.Time")

# Social Point Events ----
interactions_point_events <- events %>% 
  filter(Behavioral.category=="Interactions",
         Status=="POINT") %>% 
  select('Time','Behavior','R.Time')
interactions_point_events <- rename(interactions_point_events, Interactions_Point=Behavior)

# Merging Point & State Events ----

interactions_1Hz <- full_join(interactions_1Hz,
                              interactions_point_events,
                              by="R.Time")

# Eye State Point Events ----

eye_point_events <- events %>% 
  filter(Behavioral.category=="Eye State",
         Status=="POINT") %>% 
  select('Time','Behavior','R.Time')
eye_point_events <- rename(eye_point_events, Eye_Point=Behavior)

# Merging Point & State Events ----

eyeState_1Hz <- full_join(eyeState_1Hz,
                        eye_point_events,
                        by="R.Time")

# Making full ethogram ----
ethogram <- cbind(behavior_1Hz,
                  drifting_1Hz$Drifting_State,
                  location_1Hz$Location_State, 
                  position_1Hz$Position_State, 
                  eyeState_1Hz$Eye_State,
                  eyeState_1Hz$Eye_Point,
                  interactions_1Hz$Interactions_State,
                  interactions_1Hz$Interactions_Point)

ethogram <- ethogram %>% 
  select('Seconds', 'R.Time', 'Behavior_State', 'Behavior_Point', 6:12)

colnames(ethogram) <- c("Seconds",
                        "R.Time",
                        "Behavior_State",
                        "Behavior_Point",
                        "Drifting_State",
                        "Location_State",
                        "Position_State",
                        "Eye_State",
                        "Eye_Point",
                        "Interactions_State",
                        "Interactions_Point")

# Save processed video scoring data ----
write.csv(ethogram,here("Data",paste(SealID,
                                     "_04_Ethogram_",
                                     camera,"_",
                                     start_str,"_",
                                     end_str,"_",
                                     etho_freq,".csv",
                                     sep="")), row.names = FALSE)

# UNUSED CODE ----
# Check sequence for any deviation from Apnea > Breath > First Breath > Last Breath > Apnea etc.

# for (i in 2:nrow(behavior_events)){
#   if (behavior_events$Behavior[i] == "Apnea"){
#     if (behavior_events$Behavior[i-1] != "Last Breath"){
#       paste("Missing 'Breath' end bradycardia comment, check timestamp",behavior_events$R.Time[i])
#     }
#   }else if (behavior_events$Behavior[i] == "Breath"){
#     if (behavior_events$Behavior[i-1] != "Apnea"){
#       paste("Missing 'Apnea' start bradycardia comment, check timestamp",behavior_events$R.Time[i])
#     }
#   }else if (behavior_events$Behavior[i] == "First Breath"){
#     if (behavior_events$Behavior[i-1] != "Breath"){
#       paste("Missing 'Breath' end bradycardia comment, check timestamp",behavior_events$R.Time[i])
#     }
#   }else if (behavior_events$Behavior[i] == "Last Breath"){
#     if (behavior_events$Behavior[i-1] != "First Breath"){
#       paste("Missing 'Last Breath' end breathing comment, check timestamp",behavior_events$R.Time[i])
#     }
#   }else{
#     print("undefined event present")
#   }
# }