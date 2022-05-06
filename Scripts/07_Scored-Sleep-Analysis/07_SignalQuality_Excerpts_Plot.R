# Set up packages
library(ggplot2)
library("car")
library("lubridate")
library(here)
library(tidyverse)
library(lme4)
library(reshape2)

# Reading the CSV (with path)
SignalExcerpts <- read.csv("C:/Users/jmkb9/Documents/Dissertation Sleep/Sleep_Analysis/Data/05_Signal_Quality_Excerpts_Compiled_V2.csv")

SignalExcerpts <- read.csv("C:/Users/jmkb9/Documents/Dissertation Sleep/Sleep_Analysis/Data/05_Signal_Quality_Excerpts_Challenges_Solutions_test.csv")

# Making a label column to facet by
SignalExcerpts$LABEL <- paste(SignalExcerpts$Wild.v.Captive,
                              SignalExcerpts$Active.v.SWS.v.REM,
                              SignalExcerpts$Activity,
                              SignalExcerpts$Location, sep="_")

# 
SignalExcerpts.long <- SignalExcerpts %>% gather(Signal,Value,ECG,LEEG1,REEG2,LEEG3,REEG4,-c(LABEL, Seconds))
SignalExcerpts_plot <- SignalExcerpts.long %>%  
  select('Seconds','Value','Signal','LABEL','Wild.v.Captive','Active.v.SWS.v.REM','Activity','Location') %>% 
  na.omit()

Offset_ECG <- SignalExcerpts_plot %>% 
  filter(Signal=="ECG") %>% 
  mutate(Offset_value=Value+100)
Offset_LEEG1 <- SignalExcerpts_plot %>% 
  filter(Signal=="LEEG1") %>% 
  mutate(Offset_value=Value+50)
Offset_REEG2 <- SignalExcerpts_plot %>% 
  filter(Signal=="REEG2") %>% 
  mutate(Offset_value=Value-0)
Offset_LEEG3 <- SignalExcerpts_plot %>% 
  filter(Signal=="LEEG3") %>% 
  mutate(Offset_value=Value-50)
Offset_REEG4 <- SignalExcerpts_plot %>% 
  filter(Signal=="REEG4") %>% 
  mutate(Offset_value=Value-100)

Concatenated <- rbind(Offset_ECG,Offset_LEEG1,Offset_REEG2,Offset_LEEG3,Offset_REEG4)

Concatenated_2 <- rbind(Offset_LEEG1,Offset_REEG2,Offset_LEEG3,Offset_REEG4)

levels(factor(SignalExcerpts_plot$Signal))

#scaled to show all ECG
plotA <- ggplot(data=Concatenated,aes(x=Seconds,y=Offset_value, colour=Signal)) + 
  geom_line(alpha=0.5) +
  # geom_jitter(size = 3, alpha = 0.01, width = 0.15) +
  # geom_boxplot(alpha = 0.7) +
  # geom_violin(scale=2)
  # scale_fill_manual(values=SleepState_colors) +
  xlim(11,21)+
  ylim(-250,1000) +
  facet_wrap(Wild.v.Captive ~ Location ~ Active.v.SWS.v.REM + Activity) +
  theme_classic() +
  labs(y= "Signal Quality by Location")
plotA

plotB <- ggplot(data=Offset_ECG,aes(x=Seconds,y=Offset_value, colour=Signal)) + 
  geom_line(alpha=0.5) +
  # geom_jitter(size = 3, alpha = 0.01, width = 0.15) +
  # geom_boxplot(alpha = 0.7) +
  # geom_violin(scale=2)
  # scale_fill_manual(values=SleepState_colors) +
  xlim(10,20)+
  ylim(-5000,7000) +
  facet_wrap(Wild.v.Captive ~ Location ~ Activity + Active.v.SWS.v.REM) +
  theme_classic() +
  labs(y= "Signal Quality by Location")
plotB

plotC <- ggplot(data=Concatenated_2,aes(x=Seconds,y=Offset_value, colour=Signal)) + 
  geom_line(alpha=0.5) +
  # geom_jitter(size = 3, alpha = 0.01, width = 0.15) +
  # geom_boxplot(alpha = 0.7) +
  # geom_violin(scale=2)
  # scale_fill_manual(values=SleepState_colors) +
  xlim(11,21)+
  ylim(-250,300) +
  facet_wrap(~LABEL) +
  theme_classic() +
  labs(y= "Signal Quality by Location")
plotC

#scaled to show EEG
plotD <- ggplot(data=Concatenated,aes(x=Seconds,y=Offset_value, colour=Signal)) + 
  geom_line(alpha=0.5, size=0.8) +
  # geom_jitter(size = 3, alpha = 0.01, width = 0.15) +
  # geom_boxplot(alpha = 0.7) +
  # geom_violin(scale=2)
  # scale_fill_manual(values=SleepState_colors) +
  xlim(5,15)+
  ylim(-200,400) +
  facet_wrap(~LABEL) +
  theme_classic() +
  labs(y= "Signal Quality by Location")
plotD

plotE <- ggplot(data=SignalExcerpts_plot,aes(x=Seconds,y=Value, colour=Signal)) + 
  geom_line() +
  geom_point(alpha=0.3)+
  # geom_jitter(size = 3, alpha = 0.01, width = 0.15) +
  # geom_boxplot(alpha = 0.7) +
  # geom_violin(scale=2)
  # scale_fill_manual(values=SleepState_colors) +
  xlim(20,50)+
  ylim(-200,200)+
  facet_wrap(~LABEL) +
  theme_classic() +
  labs(y= "Signal Quality by Location")
  #theme(legend.position = "none")
plotE