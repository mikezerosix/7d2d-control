#!/bin/bash
 
## 
## 7 Days to Die  - Linux dedicated server - Steamcmd - Management script 
##
## Description: Simple Bash shell script to ease management of 7 Days to Die Dedicated linux server 
## Version : 1.1, 28.11.2014
## Author: mikezerosix 
##
## --------------------------
## Quick how to for impatient
## --------------------------
## 1. log in as the user you want to run the game with (which can not be root !!!) 
## 2. copy this scrip to that user HOME and run it with param "update" : 
##    7d2d-constrol.sh update 
##   -This installs everything 
## 3. go the 7d2d directory under the HOME and edit serverconfig.xml and serveradmin.xml files for the game settings 
## 4. start the game with command 
##    7d2d-constrol.sh start
## 5. Game on, ur done  !!!!!!!
##
## To stop 
##   7d2d-constrol.sh stop  
## To update 
##   7d2d-constrol.sh stop
## To backup 
##   7d2d-constrol.sh backup
##
## Running  7d2d-constrol.sh without any parameter will print out help 
##
## ---------------------------------------------------
## Default directories in current user HOME diretory. 
## ---------------------------------------------------
##  ~/steamcmd : the steam client to install and update the game
##  ~/7d2d : the game itself, aka install dir
##  ~/7d2d-savegame : this is where I would like the save game to go to, so far I have not been able to override the default loction
##  ~/7d2d-backup : backup dir where backups are copied, auto backup on config and admin xml files on every update
##  ~/7d2d.pid : pid file (Process id) that works as lock file. Start up creates this and stop deletes this. This pevents starting the server process multiple times. Server crash leaves this file which prevents starting, delete the file to start IF you are sure process is not already running. 
##
## ------------------------
## Customizing locations 
## ------------------------
## To change file locations change the variables on top of the script
##
## ------------------------
## Variables 
## ------------------------
## steam_user =  Your steam username, Steam client will prompt for password first run. default anonymous should work ok. 
## home_dir = directory where everything is installed, make sure you have write permission to  
## bitCount = determines which version to use: 64 or 32 - bit. "_64" for 64-bit, "" for 32-bit. Currently game for linux is only 32-bit 

## NB: overwriting the SaveGameFolfer in serverconfing.xml is a bit hack-y, so it might not work 100%  
## ---------------------------------------------------------------------------------------------------


# ** CHANGE ME ** 
# ----------------------------- 
steam_user="mikezerosix"
# ----------------------------- 


# Change these values if needed 
# ----------------------------- 
HOME_DIR=~
SAVE_GAME_DIR=${HOME_DIR}/7d2d-savegame 

INSTALL_DIR=${HOME_DIR}/7d2d
BACKUP_DIR=${HOME_DIR}/7d2d-backup
PID_FILE=${HOME_DIR}/7d2d.pid  
STEAM_CMD_DIR=${HOME_DIR}/steamcmd 

# use  "_64" for 64-bit, "" for 32-bit 
bitCount=""


# Do NOT change anything below here 
# --------------------------------
echo ""
if [[ $EUID -eq 0 ]]; then
    echo "ERROR: This script must not be run using sudo or as the root user"
    exit 1
fi
if [ -z "${steam_user}" ]; then 
    echo "ERROR: No steam user entered, you need to edit this file and write your steam username into variable steam_user, like: 'steam_user="lord_brittish"'"
    exit 1
fi

if [ ! -f ${STEAM_CMD_DIR}/steamcmd.sh ]; then
  echo "" 
  echo "Steam not found, installing steam..."
  echo ""
  if [ ! -d ${STEAM_CMD_DIR} ]; then
     mkdir ${STEAM_CMD_DIR}
  fi
         
  if hash curl; then 
     curl -s http://media.steampowered.com/installer/steamcmd_linux.tar.gz | tar -xz -C ${STEAM_CMD_DIR}
  elif hash wget; then 
     wget -q http://media.steampowered.com/installer/steamcmd_linux.tar.gz -O - | tar -xz -C ${STEAM_CMD_DIR}     
  else 
    echo "No curl OR wget ??? WTF kind of server is this ?"
    exit 1
  fi
fi  

case "$1" in
  start)
    if [ -f ${PID_FILE} ]; then 
      echo "ERROR: Can not start ! The pid file ${PID_FILE} exists, program might already be running."
      echo "   If you are sure it is not running, then delete the pid file ${PID_FILE} and try again. "
      exit 1
    fi
  
    echo "Starting 7dtd..."
    ${INSTALL_DIR}/7DaysToDie.x86${bitCount} -logfile ${HOME_DIR}/7d2d.log -quit -batchmode -nographics -configfile=${INSTALL_DIR}/serverconfig.xml -dedicated &
    echo $! > ${PID_FILE} || (echo "error storing pid to ${PID_FILE}"; exit 1)  
  ;;
  
  stop)
    echo "Shutting down 7d2d..."
    if [ ! -f ${PID_FILE} ]; then 
       echo "No pid file: ${PID_FILE} assuming the service is not running."
       exit 0
    fi 
    /bin/kill -TERM `cat ${PID_FILE}`
    rm -f ${PID_FILE}
  ;;

  restart)
    $0 stop
    sleep 8
    $0 start
  ;;

  update)
    echo "Updating 7d2d..."
    $0 stop
    if [ ! -d ${BACKUP_DIR} ]; then 
      mkdir -p ${BACKUP_DIR}
    fi  
    if [ ! -d ${INSTALL_DIR} ]; then 
      mkdir -p ${INSTALL_DIR}
    fi  
    
    cp ${INSTALL_DIR}/serverconfig.xml ${BACKUP_DIR}/serverconfig.xml.`date -I`
    cp ${INSTALL_DIR}/serveradmin.xml ${BACKUP_DIR}/serveradmin.xml.`date -I`
    
    sleep 8
    ${STEAM_CMD_DIR}/steamcmd.sh +@ShutdownOnFailedCommand 1 +login "${steam_user}" +force_install_dir "${INSTALL_DIR}" +app_update 294420 validate +quit
    sleep 5 
    mv ${INSTALL_DIR}/serverconfig.xml ${INSTALL_DIR}/serverconfig.bk
    grep -v "property name=\"SaveGameFolder\"" ${INSTALL_DIR}/serverconfig.bk|grep -v "</ServerSettings>" > ${INSTALL_DIR}/serverconfig.xml
    echo "<!-- DO not edit SaveGameFolder, the value is overwritted in update by 7d2d-control.sh, edit the SAVE_GAME_DIR variable in 7d2d-constrol.sh instead -->" >> ${INSTALL_DIR}/serverconfig.xml    
    echo "    <property name=\"SaveGameFolder\" value=\"${SAVE_GAME_DIR}\" />" >> ${INSTALL_DIR}/serverconfig.xml
    echo "</ServerSettings>" >> ${INSTALL_DIR}/serverconfig.xml
    
    echo ""
    echo " Update finished. Check serverconfig.xml and admin.xml before starting ! You can find backups in: ${BACKUP_DIR} "
  ;;

  backup) 
    echo "Backuping 7d2d savegames from ${SAVE_GAME_DIR}..."
    $0 stop
    sleep 8
    if ! -d ${BACKUP_DIR}; then 
      mkdir ${BACKUP_DIR}
    fi  
    tar cvzf ${BACKUP_DIR}/savegame-`date -I`.ta.gz ${SAVE_GAME_DIR} 
    $0 start    
  ;;   
  help) 
    grep "^##" $0 
    $0 
    ;;  
  *)
    echo "Usage: $0 start | stop | restart | update | backup |help"
  ;;
esac

echo ""
