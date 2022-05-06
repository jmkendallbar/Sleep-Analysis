library(ggplot2)
library("car")
library("lubridate")
library(here)
library(tidyverse)
library(lme4)
library(hrbrthemes)
library(lmerTest)
library(cowplot)

# PROCESS DATA ----
ON_ANIMAL_TIMES <- metadata %>% 
  filter(description=='ON.ANIMAL') %>% 
  select(R.Time)

SignalData <- read.csv(here("Data","05_Signal_Quality_Data.csv"))
SignalData$R.Time <- as.POSIXct(SignalData[,2], format = "%m/%d/%Y %H:%M:%OS")

SignalData <- SignalData %>% 
  na.omit() %>% 
  arrange(Seal.ID)
for (i in 1:nrow(SignalData)){
    SignalData$Deployment[i] <- metadata$value[metadata$TestID==SignalData$Seal.ID[i] & 
                                                 metadata$description=='Deployment']
    SignalData$Seal.Number[i] <- metadata$value[metadata$TestID==SignalData$Seal.ID[i] & 
                                                 metadata$description=='Seal.Number']
    SignalData$Version[i] <- metadata$value[metadata$TestID==SignalData$Seal.ID[i] & 
                                                 metadata$description=='Version']
    SignalData$AGE[i] <- metadata$value[metadata$TestID==SignalData$Seal.ID[i] & 
                                                  metadata$description=='Age']
}

Raw_Metadata <- read.csv(here("Data","00_Raw_Scoring_Metadata.csv"))
EnterWater <- Raw_Metadata %>% 
  filter(CommentText=='Animal Enters Water') %>% 
  select('Seconds','SealID','CommentText')

ExitWater <- Raw_Metadata %>% 
  filter(CommentText=='Animal Exits Water') %>% 
  select('Seconds','SealID','CommentText')
Failed_Seconds=numeric()

for (i in 1:length(SealIDs)){
  SealID <- SealIDs[i] # cycle through all seals to find failures
  Seal_EnterWater <- EnterWater %>% filter(SealID==SealIDs[i])
  Seal_ExitWater  <- ExitWater %>% filter(SealID==SealIDs[i])
  if (nrow(Seal_EnterWater)==nrow(Seal_ExitWater)){
    Failed_Seconds[i]=NA
  } else if (str_detect(metadata$value[metadata$TestID==SealID & 
                                       metadata$description=='Device.Failure'],
                        "Yes") == "TRUE" ) {
    Failed_Seconds[i]=as.numeric(metadata$value[metadata$TestID==SealID & metadata$description=='Recording.Duration_s'])
  } else {
    Failed_Seconds[i]=NA
  }
}
Failed_in_Water_Seconds <- data.frame(as.numeric(Failed_Seconds),SealIDs,'fail')
colnames(Failed_in_Water_Seconds) <- c('Seconds','SealID','CommentText')
ExitWater <- rbind(ExitWater,Failed_in_Water_Seconds)
ExitWater <- ExitWater %>% 
  na.omit() %>% 
  arrange(as.character(SealID),as.numeric(Seconds)) %>% 
  mutate(SealID=factor(SealID))
EnterWater <- EnterWater %>% 
  arrange(as.character(SealID),as.numeric(Seconds)) %>% 
  mutate(SealID=factor(SealID))

WaterData <- cbind(EnterWater,ExitWater)
colnames(WaterData) <- c('EnterSec','EnterSealID','EnterComment','ExitSec','Seal.ID','ExitComment')

Seconds_at_ON_ANIMAL <- numeric()
for (i in 1:length(SealIDs)){
  SealID <- SealIDs[i] # cycle through all seals to find failures
  Seconds_at_ON_ANIMAL[i] <- difftime(metadata$R.Time[metadata$TestID==SealIDs[i] & metadata$description=='ON.ANIMAL'],
    metadata$R.Time[metadata$TestID==SealIDs[i] & metadata$description=='Logger.Start'],
    units="secs")
  WaterData$EnterSec_Elapsed[WaterData$Seal.ID==SealIDs[i]] <- WaterData$EnterSec[WaterData$Seal.ID==SealIDs[i]] - Seconds_at_ON_ANIMAL[i]
  WaterData$ExitSec_Elapsed[WaterData$Seal.ID==SealIDs[i]] <- WaterData$ExitSec[WaterData$Seal.ID==SealIDs[i]] - Seconds_at_ON_ANIMAL[i]
}


SignalData$Seconds.on.Animal <- as.double(SignalData[,1])

daysec <- 24*3600

SignalData_clean <- SignalData %>% 
  filter(Cmt.Text=="SWS2" | Cmt.Text== "REM") %>% 
  select('Seconds.on.Animal',
         as.factor('Cmt.Text'),
         as.factor('Seal.ID'),
         as.factor('Location'),
         as.factor('Phase'),
         as.factor('AGE'),
         as.factor('Version'),
         as.factor('Deployment'),
         as.factor('Seal.Number'),
         'R.Time',
         'BEST_EEG_DELTA',
         'EEG_ICA_DELTA',
         'EEG_Pruned_DELTA',
         'EEG_Raw1_DELTA')

# Binning into Days
SignalData_clean <- SignalData_clean %>%
  mutate(Day=as.double(ifelse(Seconds.on.Animal<daysec,"0",
                    ifelse(Seconds.on.Animal<2*daysec,"1",
                           ifelse(Seconds.on.Animal<3*daysec,"2",
                                  ifelse(Seconds.on.Animal<4*daysec,"3",
                                         ifelse(Seconds.on.Animal<5*daysec,"4",
                                                ifelse(Seconds.on.Animal<5*daysec,"5","6"))))))))

# Add pair labels
Label<-numeric(NROW(SignalData_clean))
#start indexing at 1
count<-1
Label[1] <- NA
#find first sleep stage
prevStage<-SignalData_clean[1,]$Cmt.Text
#iterate each row
for(i in 2:NROW(SignalData_clean)){
  curStage<-SignalData_clean[i,]$Cmt.Text
  #if whatever the criteria is
  if(curStage=="REM" & prevStage=="SWS2"){
    #label previous
    Label[i-1]<-count
    #label current
    Label[i]<-count
    prevStage<-curStage
    count<-count+1
  }else{
    #Not a pair
    Label[i]<-NA
    prevStage<-SignalData_clean[i,]$Cmt.Text
  }}
SignalData_clean$PairLabel <- Label

calculate_mode <- function(x) {
  uniqx <- unique(x)
  uniqx[which.max(tabulate(match(x, uniqx)))]
}

SignalData_paired <- SignalData_clean %>% 
  filter(!is.na(PairLabel)) %>% 
  group_by(PairLabel,Day) %>% 
  dplyr::summarise(MinSec=min(Seconds.on.Animal,na.rm=TRUE),
                   MeanSec=mean(Seconds.on.Animal,na.rm=TRUE),
                   #Standardized=sqrt(BEST_EEG_DELTA[Cmt.Text=="SWS2"])/sqrt(BEST_EEG_DELTA[Cmt.Text=="REM"]), # ask Pete
                   Standardized = BEST_EEG_DELTA[Cmt.Text=="SWS2"]/BEST_EEG_DELTA[Cmt.Text=="REM"],
                   Seal.ID = as.factor(calculate_mode(Seal.ID)),
                   Location = as.factor(calculate_mode(Location)),
                   Version = as.factor(calculate_mode(Version)),
                   Phase = as.factor(calculate_mode(Phase)),
                   AGE = as.factor(calculate_mode(AGE)),
                   Deployment = as.factor(calculate_mode(Deployment)),
                   Seal.Number = as.factor(calculate_mode(Seal.Number)),
                   SWS = BEST_EEG_DELTA[Cmt.Text=="SWS2"],
                   REM = BEST_EEG_DELTA[Cmt.Text=="REM"]) %>% 
  mutate(PairLabel=as.numeric(PairLabel))
  
SignalData_paired$Days.Elapsed <- as.numeric(SignalData_paired$MeanSec)/(24*3600)
SignalData_paired$AGE <- factor(SignalData_paired$AGE, levels=c("(0,1]","(1,2]","(2,3]"))

SignalData_join <- left_join(by=c('Day','PairLabel'),SignalData_clean,SignalData_paired)

SignalData_binned <- SignalData_paired %>% 
  filter(!is.na(PairLabel)) %>% 
  group_by(Day,Seal.ID) %>% 
  dplyr::summarise(Mean=mean(Standardized),
                   sd=sd(Standardized),
                   max=max(Standardized),
                   min=min(Standardized),
                   Mean_SWS = mean(SWS),
                   sd_SWS = sd(SWS),
                   Mean_REM = mean(REM),
                   sd_REM = sd(REM),
                   Version = as.factor(calculate_mode(Version)),
                   Phase = as.factor(calculate_mode(Phase)),
                   Percent.Obs.Water = length(which(Location=="WATER")/length(Location)),
                   Deployment = as.factor(calculate_mode(Deployment)),
                   Seal.Number = as.factor(calculate_mode(Seal.Number)),
                   AGE = as.factor(calculate_mode(AGE)))

# Linear Mixed Effect Model where 
# Date.Time = Predictor Variable
# Can BIN data into time bins to have categorical predictor variable
# Sleep Stage = Predictor Variable
# DELTA Spectral Power = Response Variable
# WATER obs/ Total obs = Continuous predictor variable
# time in WATER / total time = Continuous Predictor variable
# AGE = Predictor variable; categorical, fixed effect
# CAPTIVE v WILD 
# % obs SHALLOW (<10m) = Continuous predictor
# % obs CONT SHELF (<200m)
# % obs AT SEA (>200m)
# SealID = random effect

# Signal quality versus time and age
# Looking at how much of the variance of standardized delta spectral power is explained by days since attachment
# and the interaction between time and age, to see if older animals have worse signal quality over time than younger animals.
# SealID is a random effect.
SignalData_binned$Day <- factor(SignalData_binned$Day)
fm1 <- lmer(Mean ~ Day * AGE + (1+Day | Seal.ID), data=SignalData_binned)
summary(fm1)
anova(fm1)

plot(fm1)

qqnorm(residuals(fm1))

# Signal quality versus time and version #
# Looking at how much of the variance of standardized delta spectral power is explained by days since attachment
# and the interaction between time and version, to see if older animals have worse signal quality over time than younger animals.
# SealID is a random effect.
fm1A <- lmer(Mean ~ Day * AGE + (1 | Seal.ID), data=SignalData_binned)
summary(fm1A)

plot(fm1A)

qqnorm(residuals(fm1A))

fm2 <- lmer(Standardized ~ Days.Elapsed * AGE + (1 | Seal.ID), data=SignalData_paired)
summary(fm2)

fm3 <- lmer(Mean ~ Day + (Day | Seal.ID) + (AGE | Percent.Obs.Water) + (AGE | Percent.Time.Water), data=SignalData_binned)

# PLOT DATA ----

LandvWater_colors<-c("LAND"="#dfc27d", #land color from divergent colorblind friendly color brewer palette
                     "WATER"="#80cdc1") #water color from divergent colorblind friendly color brewer palette

SleepState_colors<-c("SWS2" = "#6CAFE2",
                     "REM" = "#FFC000")

SleepState_allcolors <- c("MVMT (from calm)"= "#FF7F7F", 
                          "JOLT (from sleep)"= "#FF7F7F",
                          "CALM (from motion)" = "#ACD7CA", 
                          "WAKE (from sleep)" = "#ACD7CA", 
                          "LS (light sleep)" = "#CFCDEB",
                          "SWS1" = "#A3CEED",
                          "SWS2" = "#6CAFE2",
                          "REM" = "#FFC000")

#ALL ANIMALS Signal v. Time (by Day)
plotA <- ggplot() + 
  geom_boxplot(data=SignalData_paired,aes(x=factor(Day), y=Standardized))+
  geom_jitter(data=SignalData_paired,aes(x=factor(Day), y=Standardized), alpha=0.2)+
  scale_y_log10()+
  theme_classic() +
  #annotate("text", x=4,y=2.25,label="REM v. SWS quantitatively distinguished")+
  labs(x="Day", y= "SWS Delta / REM Delta", title = "Signal Quality v Time (days)") +
  geom_hline(yintercept=2, linetype="dashed", color="gray")
plotA

#ALL ANIMALS Signal v. Time (by Day)
plotB <- ggplot() + 
  geom_boxplot(data=SignalData_paired,aes(x=factor(Day), y=Standardized))+
  geom_jitter(data=SignalData_paired,aes(x=factor(Day), y=Standardized), alpha=0.2)+
  scale_y_log10()+
  facet_wrap(~Version)+
  theme_classic() +
  labs(x="Day", y= "SWS Delta / REM Delta", title = "Signal Quality v Time by Version") +
  geom_hline(yintercept=2, linetype="dashed", color="gray")
plotB

#LAND v WATER across VERSION
plotC <- ggplot() + 
  geom_boxplot(data=SignalData_paired,aes(x=Location,y=Standardized,colour=factor(Location)))+
  geom_jitter(data=SignalData_paired,aes(x=Location,y=Standardized,colour=factor(Location)),alpha=0.2)+
  scale_y_log10()+
  theme_classic() +
  geom_hline(yintercept=2, linetype="dashed", color="gray")+
  labs(x="Location", y= "SWS Delta / REM Delta", title = "Signal Quality v Location", color='Location') +
  theme(legend.position = c(.85,.85))
plotC

#LAND v WATER across VERSION
plotD <- ggplot() + 
  geom_boxplot(data=SignalData_paired,aes(x=Location,y=Standardized,colour=factor(Location)))+
  geom_jitter(data=SignalData_paired,aes(x=Location,y=Standardized,colour=factor(Location)),alpha=0.2)+
  facet_wrap(~Version)+
  scale_y_log10()+
  theme_classic() +
  geom_hline(yintercept=2, linetype="dashed", color="gray")+
  labs(x="Location", y= "SWS Delta / REM Delta", title = "Signal Quality v Location by Version (V1, V2, V3)", color='Location')+
  theme(legend.position = "none")
  #theme(legend.position = c(.85,.85))
plotD

#ALL ANIMALS Signal v AGE
plotE <- ggplot() + 
  geom_boxplot(data=SignalData_paired,aes(x=AGE,y=Standardized))+
  geom_jitter(data=SignalData_paired,aes(x=AGE,y=Standardized),alpha=0.2)+
  scale_y_log10()+
  theme_classic() +
  geom_hline(yintercept=2, linetype="dashed", color="gray")+
  labs(x="Age of Seal",y= "SWS Delta / REM Delta", title="Signal Quality v Age") +
  theme(legend.position = "top")
plotE

#LAND v WATER across AGE
plotF <- ggplot() + 
  geom_boxplot(data=SignalData_paired,aes(x=Location,y=Standardized,colour=factor(Location)))+
  geom_jitter(data=SignalData_paired,aes(x=Location,y=Standardized,colour=factor(Location)),alpha=0.2)+
  facet_wrap(~AGE)+
  scale_y_log10()+
  theme_classic() +
  geom_hline(yintercept=2, linetype="dashed", color="gray")+
  labs(x="Location", y= "SWS Delta / REM Delta", title = "Signal Quality v Location by Age (years)", color='Location')+
  theme(legend.position = "none")
#theme(legend.position = c(.85,.85))
plotF

top_row <- plot_grid(plotA,plotB,labels="AUTO", rel_widths=c(1,2))
middle_row <- plot_grid(plotC,plotD,labels=c("C","D"), rel_widths=c(1,2))
bottom_row <- plot_grid(plotE,plotF,labels=c("E","F"), rel_widths=c(1,2))
Signal_Quality_plots<- plot_grid(top_row,middle_row,bottom_row,nrow=3)
ggsave(here("Figures",paste("06_Signal_Quality_plots.pdf",sep="")),Signal_Quality_plots, width= 10,height = 10,units="in",dpi=300)


#THE QUESTION OF AGE - showing all nuances
ggplot(data=SignalData_paired,aes(x=AGE,y=Standardized)) + 
  geom_violin(aes(x=AGE))+
  geom_jitter(alpha=0.4, aes(x=AGE,y=Standardized, color=factor(Location), shape=factor(Version)))+
  scale_y_log10()+
  theme_classic() +
  geom_hline(yintercept=2, linetype="dashed", color="gray")+
  labs(x="Age of Seal",y= "SWS Delta / REM Delta") +
  theme(legend.position = "top")



#ALL ANIMALS over time (by seconds showing land v. water)
ggplot(data=SignalData_paired,aes(x=Days.Elapsed,y=Standardized,colour=factor(Location))) + 
  geom_point(size = 3, alpha = 0.4) +
  scale_y_log10()+
  theme_classic() +
  labs(y= "Delta Spectral Power (0.5 to 4Hz)") +
  geom_hline(yintercept=2, linetype="dashed", color="gray")+
  theme(legend.position = "none")

lm_fit <- lm(MeanSec ~ Standardized, data=SignalData_paired)
summary(lm_fit)

ggplot(data=SignalData_paired,aes(x=Days.Elapsed,y=Standardized,colour=factor(Day))) + 
  geom_point(size = 3, alpha = 0.4) +
  scale_y_log10()+
  facet_wrap(~Seal.ID) +
  theme_classic() +
  #geom_smooth(method="lm")+
  labs(y= "Delta Spectral Power (0.5 to 4Hz)", x='Days') +
  theme(legend.position = "none")

plotA <- ggplot() + 
  geom_rect(data=WaterData, aes(xmin=EnterSec_Elapsed,xmax=ExitSec_Elapsed,ymin=0,ymax=500), fill='blue', alpha=0.2)+
  geom_point(data=SignalData_clean,aes(x=Seconds.on.Animal,y=BEST_EEG_DELTA,colour=factor(Cmt.Text)),size = 1, alpha = 0.2) +
  facet_wrap(~factor(Seal.ID), nrow=length(SealIDs)/2, ncol = 2) +
  scale_y_log10()+
  theme_classic() +
  geom_smooth(method="lm")+
  labs(y= "Delta Spectral Power (0.5 to 4Hz)", x = "Days") +
  theme(legend.position = "none")
plotA

Captive <- c('test12_Wednesday','test23_AshyAshley','test24_BerthaBeauty','test25_ComaCourtney','test26_DreamyDenise')
Captive_SignalData_paired <- SignalData_paired %>% 
  filter(Seal.ID %in% Captive) %>% 
  droplevels()
Captive_WaterData <- WaterData %>% 
  filter(Seal.ID %in% Captive) %>% 
  droplevels()

plotB <- ggplot()+
  geom_segment(data = Captive_SignalData_paired, aes(x=SWS, 
                                             xend=REM, 
                                             y=Days.Elapsed, 
                                             yend=Days.Elapsed),color="grey")+
  facet_wrap(~Seal.ID, nrow=1, ncol = length(SealIDs)) +
  geom_rect(data=Captive_WaterData, aes(xmin=0,xmax=500,ymin=EnterSec_Elapsed/(24*3600),ymax=ExitSec_Elapsed/(24*3600)), fill='#6CAFE2', alpha=0.3)+
  geom_point(data = Captive_SignalData_paired, aes(x=SWS, y=Days.Elapsed), color = "#6CAFE2", size=3, alpha = 1)+
  geom_point(data = Captive_SignalData_paired, aes(x=REM, y=Days.Elapsed),color = "#FFC000", size=3, alpha = 1) +
  theme_classic() +
  scale_x_log10()+
  scale_y_reverse()+
  xlab("Delta Spectral Power")+
  ylab("Days Since Attachment")
plotB
ggsave(here("Figures",paste("06_SignalQuality.pdf",sep="")),plotB, width= 15,height = 10,units="in",dpi=300)


# Plot with raw data, linear geom smooth, and water rectangles ----
plotC <- ggplot()+
  geom_segment(data = Captive_SignalData_paired, aes(x=SWS, 
                                                     xend=REM, 
                                                     y=Days.Elapsed, 
                                                     yend=Days.Elapsed,colour=Location))+
  facet_wrap(~Seal.ID, nrow=1, ncol = length(SealIDs)) +
  geom_rect(data=Captive_WaterData, aes(xmin=0,xmax=500,ymin=EnterSec_Elapsed/(24*3600),ymax=ExitSec_Elapsed/(24*3600)), fill='#6CAFE2', alpha=0.3)+
  #geom_point(data = Captive_SignalData_paired, aes(x=SWS, y=Days.Elapsed), color = "#6CAFE2", size=1, alpha = 1)+
  #geom_point(data = Captive_SignalData_paired, aes(x=REM, y=Days.Elapsed),color = "#FFC000", size=1, alpha = 1) +
  theme_classic() +
  scale_x_log10()+
  scale_y_reverse()+
  xlab("Delta Spectral Power")+
  ylab("Days Since Attachment")
plotC
ggsave(here("Figures",paste("06_SignalQuality_Lines.pdf",sep="")),plotC, width= 15,height = 10,units="in",dpi=300)

# Plot with raw data, linear geom smooth, and water rectangles ----
plotD <- ggplot() + 
  geom_point(data=SignalData_clean,aes(x=Seconds.on.Animal/(24*3600),y=BEST_EEG_DELTA,colour=factor(Cmt.Text)),size = 2, alpha = 0.4) +
  geom_rect(data=WaterData, aes(ymin=0,ymax=500,xmin=EnterSec_Elapsed/(24*3600),xmax=ExitSec_Elapsed/(24*3600)), fill='#6CAFE2', alpha=0.2)+
  facet_wrap(~factor(Seal.ID), nrow=length(SealIDs)/2, ncol = 2) +
  scale_y_log10()+
  theme_classic() +
  geom_smooth(data=SignalData_clean,aes(x=Seconds.on.Animal/(24*3600),y=BEST_EEG_DELTA, colour=factor(Cmt.Text)),method="lm")+
  labs(y= "Delta Spectral Power (0.5 to 4Hz)", x = "Days") +
  theme(legend.position = "none")
plotD
ggsave(here("Figures",paste("06_SignalQuality_Regressions.png",sep="")),plotD, width= 10,height = 10,units="in",dpi=300)


plotA <- ggplot(data=SignalData_clean,aes(x=Phase,y=BEST_EEG_DELTA,colour=factor(Phase))) + 
  geom_boxplot(aes(x=Phase)) +
  geom_jitter(size=1, alpha=0.3) +
  scale_y_log10()+
  theme_classic() +
  labs(y= "Delta Spectral Power (0.5 to 4Hz)", x = "Days") +
  theme(legend.position = "none")
plotA

plotE <- ggplot(data=SignalData_paired,aes(x=Location,y=Standardized,colour=factor(Location))) + 
  geom_boxplot(aes(x=Location)) +
  # geom_jitter(size = 3, alpha = 0.01, width = 0.15) +
  # geom_boxplot(alpha = 0.7) +
  # geom_violin(scale=2)
  # scale_fill_manual(values=SleepState_colors) +
  geom_jitter(alpha=0.2)+
  theme_classic() +
  scale_y_log10()+
  labs(y= "log(SWS Delta / REM Delta)") +
  theme(legend.position = "none",text=element_text(size=12, family="Montserrat"))
plotE
ggsave(here("Figures",paste("06_SignalQuality_LandvWater_Boxplot.png",sep="")),plotE, width= 4,height = 6,units="in",dpi=300)

plotF <- ggplot() + 
  geom_boxplot(data=SignalData_paired,aes(x=Day,y=Standardized,colour=factor(Day))) +
  geom_jitter(size = 3, alpha = 0.01, width = 0.15) +
  # geom_boxplot(alpha = 0.7) +
  # geom_violin(scale=2)
  # scale_fill_manual(values=SleepState_colors) +
  #geom_jitter(data=SignalData_paired,aes(x=Days.Elapsed,y=Standardized,colour=factor(Location)),alpha=0.2)+
  theme_classic() +
  scale_y_log10()+
  labs(y= "log(SWS Delta / REM Delta)")
plotF
ggsave(here("Figures",paste("06_SignalQuality_Days_Boxplot.png",sep="")),plotF, width= 4,height = 6,units="in",dpi=300)


Signal.by.Version <- ggplot() + 
  geom_boxplot(data=SignalData_paired,aes(x=factor(Day),y=Standardized)) +
  # geom_jitter(size = 3, alpha = 0.01, width = 0.15) +
  # geom_boxplot(alpha = 0.7) +
  # geom_violin(scale=2)
  # scale_fill_manual(values=SleepState_colors) +
  facet_wrap(~Version) +
  geom_jitter(data=SignalData_paired,aes(x=factor(Day),y=Standardized), alpha=0.2, width=0.3)+
  theme_classic() +
  scale_y_log10()+
  geom_hline(yintercept=2, linetype="dashed", color="gray")+
  theme(legend.position = "none")+
  labs(x="Day", y= "SWS Delta / REM Delta")
Signal.by.Version
ggsave(here("Figures",paste("06_SignalQuality_Version_DayBoxplots.png",sep="")),Signal.by.Version, width= 6,height = 6,units="in",dpi=300)

Signal.by.Location <- ggplot(data=SignalData_paired,aes(x=Location,y=Standardized,colour=factor(Location))) + 
  geom_boxplot(aes(x=Location)) +
  # geom_jitter(size = 3, alpha = 0.01, width = 0.15) +
  # geom_boxplot(alpha = 0.7) +
  # geom_violin(scale=2)
  # scale_fill_manual(values=SleepState_colors) +
  facet_wrap(~Version) +
  geom_jitter(alpha=0.2,width=0.2)+
  theme_classic() +
  scale_y_log10()+
  theme(legend.position = "none")+
  labs(y= "SWS Delta / REM Delta")
Signal.by.Location
ggsave(here("Figures",paste("06_SignalQuality_Version_LocationBoxplots.png",sep="")),Signal.by.Location, width= 6,height = 6,units="in",dpi=300)


plotD <- ggplot(data=SignalData_paired,aes(x=Location,y=Standardized,colour=factor(Location))) + 
  geom_boxplot(aes(x=Location)) +
  # geom_jitter(size = 3, alpha = 0.01, width = 0.15) +
  # geom_boxplot(alpha = 0.7) +
  # geom_violin(scale=2)
  # scale_fill_manual(values=SleepState_colors) +
  geom_jitter(alpha=0.2)+
  scale_y_log10()+
  theme_classic() +
  facet_wrap(~AGE)+
  labs(y= "log(SWS Delta / REM Delta)") +
  geom_hline(yintercept=2, linetype="dashed", color="gray")+
  theme(legend.position = "none")
plotD

plotE <- ggplot(data=SignalData_clean,aes(x=Cmt.Text,y=BEST_EEG_DELTA,colour=factor(Cmt.Text))) + 
  geom_violin()+
  geom_jitter(size = 1, alpha = 0.2) +
  facet_wrap(~Location) +
  scale_y_log10()+
  theme_classic() +
  labs(y= "Delta Spectral Power (0.5 to 4Hz)", x = "Days") +
  theme(legend.position = "none")
plotE




#SIGNAL QUALITY OVER TIME WITH REGRESSION LINES
plotG <- ggplot(data = SignalData_paired)+
  geom_smooth(aes(y=SWS,x=Days.Elapsed), color = "#6CAFE2")+
  geom_smooth(aes(y=REM,x=Days.Elapsed), color = "#FFC000")+ #, method="lm"
  # geom_segment(data= SignalData_binned,
  #              aes(y=Mean_SWS, 
  #                  yend=Mean_REM, 
  #                  x=Day, 
  #                  xend=Day),color="grey")+
  facet_wrap(Version~Deployment) +
  #geom_point(aes(y=SWS, x=Days.Elapsed), color = "#6CAFE2", size=1, alpha = 0.3)+
  #geom_point(aes(y=REM, x=Days.Elapsed),color = "#FFC000", size=1, alpha = 0.3) +
  geom_point(data=SignalData_binned, aes(y=Mean_SWS, x=as.numeric(Day)),color = "#6CAFE2", size=3, alpha = 0.8) +
  geom_point(data=SignalData_binned, aes(y=Mean_REM, x=as.numeric(Day)),color = "#FFC000", size=3, alpha = 0.8) +
  geom_errorbar(data=SignalData_binned, 
                aes(x=Day, y=Mean_SWS, ymin=Mean_SWS-sd_SWS,ymax=Mean_SWS+sd_SWS),
                color = "#6CAFE2",width=0.1)+
  geom_errorbar(data=SignalData_binned, 
                aes(x=Day, y=Mean_REM, ymin=Mean_REM-sd_REM,ymax=Mean_REM+sd_REM),
                color = "#FFC000",width=0.1)+
  geom_rect(data=Signa)
  theme_classic() +
  scale_y_log10(breaks=c(0.1,1,10,100,1000),limits=c(0.1,1000))+
  xlab("Days Since Attachment")+
  ylab("Delta Spectral Power")
plotG
plotG$layers
  
fm1 <- lmer(SWS ~ Days.Elapsed + (1+Days.Elapsed | SealID), data=SignalData_paired)
summary(fm1)
coef(fm1)

fm2 <- lmer(REM ~ Days.Elapsed + (1+Days.Elapsed | SealID), data=SignalData_paired)
summary(fm2)
coef(fm2)



# EnterWater <- SignalData %>% 
#   filter(Location=="WATER" & Seal.ID =="test12_Wednesday")
# 
# EnterWater <- WaterData %>% 
#   filter(Cmt.Text=="Animal Enters Water" & Seal.ID =="test12_Wednesday")
# ExitsWater <- WaterData %>% 
#   filter(Cmt.Text=="Animal Exits Water" & Seal.ID =="test12_Wednesday")
# 
# WaterData2 <- full_join(EnterWater,ExitsWater)
# 
# EnterWater <- WaterData$Seconds.on.Animal[WaterData$Cmt.Text=="Animal Enters Water"]/(24*3600)
# ExitWater <- WaterData$Seconds.on.Animal[WaterData$Cmt.Text=="Animal Exits Water"]/(24*3600)
# plotA <- ggplot(data=WaterData)+
#   geom_rect(data=EnterWater, aes(xmin = EnterWater,xmax = ExitWater,
#                                        ymin = 0, ymax = 100))
# plotA

geom_rect(aes(xmin = WaterData$Seconds.on.Animal[WaterData$Cmt.Text=="Animal Enters Water"],
              xmax = WaterData$Seconds.on.Animal[WaterData$Cmt.Text=="Animal Exits Water"],
              ymin = 0, ymax = 100)) +

ggsave(here("Figures",paste(SignalData$Seal.ID[1],"_06_SignalQuality.png",sep="")),plotA, width= 5,height = 5,units="in",dpi=300)



