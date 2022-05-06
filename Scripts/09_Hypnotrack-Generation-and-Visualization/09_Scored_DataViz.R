library(rayshader)
library(ggplot2)
library(lubridate)
library(here)
library(tidyverse)
library(ggeasy)
library(scales)

# READ IN HYPNOTRACK (exported from Matlab) ----
hypnotrack_freq <-  5
hypnotrack <- read.csv(here("Data",paste(SealID,"_09_Hypnotrack_",scorer,"_",hypnotrack_freq,"Hz.csv",sep="")))
names(hypnotrack) <- gsub(x = names(hypnotrack), pattern = "_", replacement = ".")  
hypnotrack <- hypnotrack %>%
  filter(!is.na(ODBA))

hypnotrack$R.Time <- as.POSIXct(hypnotrack$R.Time)
hypnotrack$timebins <- cut(hypnotrack$R.Time, breaks='30 sec')
hypnotrack_30s <- hypnotrack %>%
  group_by(timebins) %>% 
  dplyr::summarise(Sleep.Code = calculate_mode(Sleep.Code),
                   Simple.Sleep.Code = calculate_mode(Simple.Sleep.Code),
                   Sleep.Num = calculate_mode(Sleep.Num),
                   Simple.Sleep.Num = calculate_mode(Sleep.Num),
                   Resp.Code = calculate_mode(Resp.Code),
                   Resp.Num = calculate_mode(Resp.Num),
                   Water.Code = calculate_mode(Water.Code),
                   Water.Num = calculate_mode(Water.Num),
                   pitch = mean(pitch),
                   roll = mean(roll),
                   heading = mean(heading),
                   Depth = mean(Depth),
                   speed = mean(speed),
                   ODBA = mean(ODBA),
                   R.Time = as.POSIXct(calculate_mode(timebins)))
hypnotrack_30s$Time_s_per_day = period_to_seconds(hms(format(hypnotrack_30s$R.Time, format='%H:%M:%S')))
hypnotrack_30s$Time = as.POSIXct(format(hypnotrack_30s$R.Time, format='%H:%M:%S'),format='%H:%M:%S')
hypnotrack_30s$Date = floor_date(hypnotrack_30s$R.Time, unit = "day")

hypnotrack$Time = as.POSIXct(format(hypnotrack$R.Time, format='%H:%M:%S'),format='%H:%M:%S')
hypnotrack$Date = floor_date(hypnotrack$R.Time, unit = "day")

hypnotrack$Simple.Sleep.Code <- factor(hypnotrack$Simple.Sleep.Code, 
                                       levels = c("Unscorable", "Active Waking", "Quiet Waking",
                                                  "Drowsiness","SWS","REM"))

write.csv(hypnotrack_30s,here("Data",paste(SealID,"_08_hypnotrack_30s_",scorer,".csv",sep="")), row.names = FALSE)

Depth_label <- data.frame(Depth = (-hypnotrack[which(hypnotrack$Depth == max(hypnotrack$Depth)),"Depth"]/100)-5, 
                     R.Time = hypnotrack[which(hypnotrack$Depth == max(hypnotrack$Depth)), "R.Time"],
                     Time = hypnotrack[which(hypnotrack$Depth == max(hypnotrack$Depth)), "Time"],
                     Date = hypnotrack[which(hypnotrack$Depth == max(hypnotrack$Depth)), "Date"],
                     text = paste("Max depth=",floor(max(hypnotrack$Depth)), "m at", 
                                  hypnotrack[which(hypnotrack$Depth == max(hypnotrack$Depth)),"R.Time"]))

Roll_dots <- data.frame(Height = 11.5, 
                          R.Time = hypnotrack[which(abs(hypnotrack$roll) > 2), "R.Time"],
                          Time = hypnotrack[which(abs(hypnotrack$roll) > 2), "Time"],
                          Date = hypnotrack[which(abs(hypnotrack$roll) > 2), "Date"])

Roll_dots$consecutive <- c(NA,diff(Roll_dots$R.Time)<2)
sum(rle(Roll_dots$consecutive)$lengths > 100)

long_rolls <- rle(Roll_dots$consecutive) %>% #STORE CONSECUTIVE VALUES
  unclass() %>%
  as.data.frame() %>%
  mutate(end = cumsum(lengths),
         start = c(1, dplyr::lag(end)[-1] + 1)) %>%
  magrittr::extract(c(1,2,4,3)) %>% # To re-order start before end for display
  filter(lengths>100)

long_roll_list = list()
for (i in 1:nrow(long_rolls)){
  long_roll_list[[i]]<- Roll_dots[long_rolls$start[i]:long_rolls$end[i],]
}
long_roll_dots <-  do.call(rbind, long_roll_list)

Drift_dots <- data.frame(Height = -11.5, 
                        R.Time = hypnotrack[which(hypnotrack$Depth > 2 & hypnotrack$ODBA<3), "R.Time"],
                        Time = hypnotrack[which(abs(hypnotrack$roll) > 2), "Time"],
                        Date = hypnotrack[which(abs(hypnotrack$roll) > 2), "Date"])

base_breaks <- function(n = 10){
  function(x) {
    axisTicks(log10(range(x, na.rm = TRUE)), log = TRUE, n = n)
  }
}

stats <- hypnotrack %>%
  group_by(Simple.Sleep.Code) %>%
  dplyr::summarize(Mean.Depth = mean(Depth),
                   SD.Depth = sd(Depth), #giving wrong value for some reason
                   Count=n(),
                   Mean.Diff.Depth = mean(diff(Depth)),
                   SD.Diff.Depth = sd(diff(Depth)),
                   Mean.ODBA = mean(ODBA),
                   SD.ODBA = sd(ODBA),
                   Mean.pitch = mean(pitch),
                   SD.pitch = sd(pitch),
                   Mean.roll = mean(abs(roll))*(180/pi),
                   SD.roll = sd(abs(roll))*(180/pi),
                   Mean.heading = mean(heading),
                   SD.heading = sd(heading),
                   Mean.Diff.heading = mean(diff(heading)),
                   SD.Diff.heading = sd(diff(heading)))



ODBA_plot <- ggplot()+
  #geom_histogram(data=hypnotrack,aes(x=ODBA), binwidth=0.01, fill='red',alpha=0.2)+
  geom_jitter(data=hypnotrack_30s,aes(x=Simple.Sleep.Code,y=ODBA,color=Simple.Sleep.Code),alpha=0.1, width=0.3)+
  geom_violin(data=hypnotrack,aes(x=Simple.Sleep.Code,y=ODBA,fill=Simple.Sleep.Code),alpha=0.3)+
  #geom_hline(data=stats,aes(yintercept=Mean.ODBA, color=Simple.Sleep.Code))+
  scale_fill_manual(values=simple.sleep.col)+
  scale_color_manual(values=simple.sleep.col)+
  #facet_grid(rows=vars(Simple.Sleep.Code))+
  scale_y_log10(labels=comma)+
  labs(x='Sleep Stage',y='Overall Dynamic Body Acceleration', title='Activity v Sleep Stage')+
  theme_classic()
ODBA_plot


hypnotrack_30s$Simple.Sleep.Code <- factor(hypnotrack_30s$Simple.Sleep.Code, 
                                       levels = c("Unscorable", "Active Waking", "Quiet Waking",
                                                  "Drowsiness","SWS","REM"))

roll_plot <- ggplot()+
  #geom_histogram(data=hypnotrack,aes(x=ODBA), binwidth=0.01, fill='red',alpha=0.2)+
  geom_density(data=hypnotrack,aes(y=abs(roll*(180/pi)), fill=Simple.Sleep.Code),alpha=0.8)+
  geom_jitter(data=hypnotrack_30s,aes(x=0.1,y=abs(roll*(180/pi)),color=Simple.Sleep.Code),alpha=0.1, width=0.01)+
  #geom_violin(data=hypnotrack,aes(x=Simple.Sleep.Code,y=abs(roll*(180/pi)),fill=Simple.Sleep.Code),alpha=0.3)+
  #geom_hline(data=stats,aes(yintercept=Mean.ODBA, color=Simple.Sleep.Code))+
  geom_text(data = stats, aes(x=0.11,y=Mean.roll-20,
                              label = paste(floor(Mean.roll),"degrees ±",floor(SD.roll))), size=3, hjust=1)+
  geom_point(data=stats, aes(x=0.12,y=Mean.roll,color=Simple.Sleep.Code))+
  geom_errorbar(data=stats, aes(x=0.12,
                                y=Mean.roll,
                                ymin=Mean.roll-SD.roll,
                                ymax=Mean.roll+SD.roll,
                                color=Simple.Sleep.Code), width=0.01)+
  geom_hline(data=stats,aes(yintercept=Mean.roll, color=Simple.Sleep.Code))+
  facet_grid(cols=vars(Simple.Sleep.Code))+
  scale_fill_manual(values=simple.sleep.col)+
  scale_color_manual(values=simple.sleep.col)+
  scale_x_continuous(labels = scales::percent)+
  scale_y_reverse()+
  #facet_grid(rows=vars(Simple.Sleep.Code))+
  labs(x='% of Observations',y='Roll in Degrees (absolute value)', title='Roll across Sleep State')+
  theme_classic()
roll_plot

ODBA_density <- ggplot()+
  #geom_histogram(data=hypnotrack,aes(x=ODBA), binwidth=0.01, fill='red',alpha=0.2)+
  geom_density(data=hypnotrack,aes(y=ODBA,fill=Simple.Sleep.Code),alpha=0.8)+
  geom_text(data = stats, aes(x=0.11,y=Mean.ODBA-20,
                              label = paste(floor(Mean.ODBA),"degrees ±",floor(SD.ODBA))), size=3, hjust=1)+
  geom_point(data=stats, aes(x=0.12,y=Mean.ODBA,color=Simple.Sleep.Code))+
  geom_errorbar(data=stats, aes(x=0.12,
                                y=Mean.ODBA,
                                ymin=Mean.ODBA-SD.ODBA,
                                ymax=Mean.ODBA+SD.ODBA,
                                color=Simple.Sleep.Code), width=0.01)+
  geom_hline(data=stats,aes(yintercept=Mean.ODBA, color=Simple.Sleep.Code))+
  scale_fill_manual(values=simple.sleep.col)+
  scale_color_manual(values=simple.sleep.col)+
  facet_grid(cols=vars(Simple.Sleep.Code))+
  scale_y_log10(labels=comma)+
  labs(x="% of observations",y="Activity (Overall Dynamic Body Acceleration)",title="Activity across Sleep State")+
  scale_x_continuous(labels = scales::percent)+
  theme_classic()
ODBA_density

Depth_density <- ggplot()+
  #geom_histogram(data=hypnotrack,aes(x=ODBA), binwidth=0.01, fill='red',alpha=0.2)+
  geom_density(data=hypnotrack,aes(y=Depth, fill=Simple.Sleep.Code),alpha=0.8)+
  geom_jitter(data=hypnotrack_30s,aes(x=0.0275,y=Depth,color=Simple.Sleep.Code),alpha=0.1, width=0.005)+
  geom_hline(data=stats,aes(yintercept=Mean.Depth, color=Simple.Sleep.Code))+
  geom_text(data = stats, aes(x=0.0195,y=Mean.Depth-10, 
                              label = paste(floor(Mean.Depth),"m ±",floor(sd(hypnotrack[hypnotrack$Simple.Sleep.Code=='Active Waking',"Depth"])))), size=3, hjust=1)+
  geom_point(data=stats, aes(x=0.02,y=Mean.Depth,color=Simple.Sleep.Code))+
  geom_errorbar(data=stats, aes(x=0.02,
                             ymin=Mean.Depth-sd(hypnotrack[hypnotrack$Simple.Sleep.Code=='Active Waking',"Depth"]),
                             ymax=Mean.Depth+sd(hypnotrack[hypnotrack$Simple.Sleep.Code=='Active Waking',"Depth"]),
                             color=Simple.Sleep.Code), width=0.002)+
  scale_fill_manual(values=simple.sleep.col)+
  scale_color_manual(values=simple.sleep.col)+
  facet_grid(cols=vars(Simple.Sleep.Code))+
  scale_x_continuous(labels = scales::percent)+
  labs(x="% of observations",y="Depth (m)",title="Depth across Sleep State")+
  scale_y_reverse()+
  theme_classic()
Depth_density


hypnotrack_30s$diff.heading <- c(diff(hypnotrack_30s$heading),NA)
hypnotrack_30s <- hypnotrack_30s %>% 
  filter(!is.na(diff.heading))
diff_stats <- hypnotrack_30s %>% 
  group_by(Simple.Sleep.Code) %>% 
  summarise(Mean.Diff.heading = mean(diff.heading),
            SD.Diff.heading = sd(diff.heading))

Heading_density <- ggplot()+
  #geom_histogram(data=hypnotrack,aes(x=ODBA), binwidth=0.01, fill='red',alpha=0.2)+
  geom_density(data=hypnotrack_30s,aes(y=diff.heading, fill=Simple.Sleep.Code),alpha=0.8)+
  geom_jitter(data=hypnotrack_30s,aes(x=2.2,y=diff.heading,color=Simple.Sleep.Code),alpha=0.1, width=0.3)+
  geom_hline(data=diff_stats,aes(yintercept=Mean.Diff.heading, color=Simple.Sleep.Code))+
  geom_text(data=diff_stats, aes(x=1.75,y=Mean.Diff.heading-1, 
                              label = paste(round(Mean.Diff.heading,digits=1),"deg ±",round(SD.Diff.heading,digits=1))), size=3, hjust=1)+
  geom_point(data=diff_stats, aes(x=1.75,y=Mean.Diff.heading,color=Simple.Sleep.Code))+
  geom_errorbar(data=diff_stats, aes(x=1.75,
                                ymin=Mean.Diff.heading-SD.Diff.heading,
                                ymax=Mean.Diff.heading+SD.Diff.heading,
                                color=Simple.Sleep.Code), width=0.002)+
  scale_fill_manual(values=simple.sleep.col)+
  scale_color_manual(values=simple.sleep.col)+
  facet_grid(cols=vars(Simple.Sleep.Code))+
  scale_x_continuous(labels = scales::percent)+
  labs(x="% of observations",y="Change in Heading (degrees)",title="Heading Change across Sleep State")+
  theme_classic()
Heading_density

sleep_motion <- plot_grid(nrow=2,roll_plot,ODBA_density, Depth_density,Heading_density,labels='AUTO')

ggsave(here("Figures",paste(SealID,"_08_sleep_motion_Plot.png",sep="")),sleep_motion, width= 15,height = 9,units="in",dpi=300)
ggsave(here("Figures",paste(SealID,"_08_sleep_motion_Plot.pdf",sep="")),sleep_motion, width= 15,height = 9,units="in",dpi=300)


# ADDING ODBA, Roll, and Depth to Hypnoplot

hypnotrack_plot <- ggplot()+
  geom_rect(data=hypnotrack_30s,aes(xmin=min(Time),xmax=min(Time)+3600*6.5,ymin=-10,ymax=10),fill='#38497D')+
  geom_rect(data=hypnotrack_30s,aes(xmin=max(Time)-3600*4.25,xmax=max(Time),ymin=-10,ymax=10),fill='#38497D')+
  geom_line(data=hypnotrack_30s,aes(x= Time, y=ODBA+1.5), color='grey')+
  geom_line(data=hypnotrack_30s,aes(x=Time, y=(-Depth/100)-5), color='grey')+
  geom_line(data=hypnotrack_30s,aes(x=Time, y=roll+8), color='grey')+
  geom_line(data=hypnotrack_30s,aes(x=Time, y=Sleep.Num), color='grey')+
  geom_point(data=hypnotrack_30s,aes(x= Time, y=Sleep.Num, color=Sleep.Code), show.legend = FALSE)+
  geom_rect(data=hypnotrack_30s,aes(xmin=Time,xmax=Time+30,ymin=-3,ymax=1, fill=Sleep.Code),size=0)+
  annotate('text', x = floor_date(hypnotrack_30s$Time, unit = "day"), y = 8, label = "Roll", hjust=1)+
  annotate('text', x = floor_date(hypnotrack_30s$Time, unit = "day"), y = 4, label = "ODBA", hjust=1)+
  annotate('text', x = floor_date(hypnotrack_30s$Time, unit = "day"), y = 0, label = "Sleep State", hjust=1)+
  annotate('text', x = floor_date(hypnotrack_30s$Time, unit = "day"), y = -4, label = "Respiration", hjust=1)+
  annotate('text', x = floor_date(hypnotrack_30s$Time, unit = "day"), y = -8, label = "Depth", hjust=1)+
  geom_text(data = Depth_label, aes(x=as.POSIXct(Time)+360, y=Depth-1.5, label = text), size=3, hjust=0)+
  geom_point(data = Depth_label, aes(x=as.POSIXct(Time), y=Depth), color='#F0995E', size=3, alpha = 0.8)+
  geom_point(data = long_roll_dots, aes(x=as.POSIXct(Time), y=11), color='#F0995E', size=1, alpha = 0.8)+
  #geom_point(data = Drift_dots, aes(x=as.POSIXct(Time), y=Height), color='#F0995E', size=1, alpha = 0.8)+
  theme_classic()+
  scale_fill_manual(values=sleep.col)+
  scale_color_manual(values=sleep.col)+
  labs(fill='Sleep Patterns')+
  new_scale_fill()+
  geom_rect(data=hypnotrack_30s, aes(xmin=Time,xmax=Time+30,ymin=-5,ymax=-3, fill=Resp.Code))+
  scale_fill_manual(values=resp.col)+
  scale_x_datetime(labels=date_format('%H:%M',tz='PST8PDT'),
                   breaks=date_breaks("2 hours"),
                   limits=c(min(hypnotrack_30s$Time)-3600*2,max(hypnotrack_30s$Time)+20)
                   )+
  facet_grid(rows=vars(Date),scales='free_x')+
  easy_remove_y_axis()+
  labs(y = "", x="Time of Day", fill='Respiratory Patterns',
       title=paste(SealID,"Hypnogram -",info$Recording.ID,"Age",info$Age))+
  theme(legend.position='right')
hypnotrack_plot
ggsave(here("Figures",paste(SealID,"_08_Scored_HypnoTrackPlot.png",sep="")),hypnotrack_plot, width= 15,height = 9,units="in",dpi=300)
ggsave(here("Figures",paste(SealID,"_08_Scored_HypnoTrackPlot.pdf",sep="")),hypnotrack_plot, width= 15,height = 9,units="in",dpi=300)


montshadow = ray_shade(montereybay, zscale = 50, lambert = FALSE)
montamb = ambient_shade(montereybay, zscale = 50)
montereybay %>%
  sphere_shade(zscale = 10, texture = "imhof1") %>%
  add_shadow(montshadow, 0.5) %>%
  add_shadow(montamb, 0) %>%
  plot_3d(montereybay, zscale = 50, fov = 0, theta = -45, phi = 45,
          windowsize = c(1000, 800), zoom = 0.75,
          water = TRUE, waterdepth = 0, wateralpha = 0.5, watercolor = "lightblue",
          waterlinecolor = "white", waterlinealpha = 0.5)
Sys.sleep(0.2)
render_snapshot(clear=TRUE)