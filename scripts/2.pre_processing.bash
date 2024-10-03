#!/bin/bash 
#-----------------------------------------------------------------------------#
# !SCRIPT: pre_processing
#
# !DESCRIPTION:
#     Script to prepare boundary and initials conditions for MONAN model.
#     
#     Performs the following tasks:
# 
#        o Creates topography, land use and static variables
#        o Ungrib GFS data
#        o Interpolates to model the grid
#        o Creates initial and boundary conditions
#        o Creates scripts to run the model and post-processing (CR: to be modified to phase 3 and 4)
#        o Integrates the MONAN model ((CR: to be modified to phase 3)
#        o Post-processing (netcdf for grib2, latlon regrid, crop) (CR: to be modified to phase 4)
#
#-----------------------------------------------------------------------------#

if [ $# -ne 4 ]
then
   echo ""
   echo "Instructions: execute the command below"
   echo ""
   echo "${0} EXP_NAME RESOLUTION LABELI FCST"
   echo ""
   echo "EXP_NAME    :: Forcing: GFS"
   echo "            :: Others options to be added later..."
   echo "RESOLUTION  :: number of points in resolution model grid, e.g: 1024002  (24 km)"
   echo "                                                                256002  (48 km)"
   echo "                                                                 40962  (120 km)"
   echo "LABELI      :: Initial date YYYYMMDDHH, e.g.: 2024010100"
   echo "FCST        :: Forecast hours, e.g.: 24, 36, 48,  etc."
   echo ""
   echo "24 hour forecast example for 24km:"
   echo "${0} GFS 1024002 2024010100 24"
   echo "72 hour forecast example for 48 km:"
   echo "${0} GFS  256002 2024090100 72"
   echo ""

   exit
fi
# Input variables:--------------------------------------
EXP=$1         #EXP=GFS
RES=$2        # RES=1024002 RES=256002
YYYYMMDDHHi=$3 #YYYYMMDDHHi=2024012000
FCST=$4        #FCST=24
#-------------------------------------------------------
# Set environment variables exports:
echo ""
echo -e "\033[1;32m==>\033[0m Moduling environment for MONAN model...\n"
. setenv.bash

echo " DIR_SCRIPTS = "${DIR_SCRIPTS}
echo " DIR_DADOS = "${DIR_DADOS}
# Standart directories variables:---------------------------------------
DIRHOMES=${DIR_SCRIPTS}; mkdir -p ${DIRHOMES}  
DIRHOMED=${DIR_DADOS};   mkdir -p ${DIRHOMED}  
SCRIPTS=${DIRHOMES}/scripts;           mkdir -p ${SCRIPTS}
DATAIN=${DIRHOMED}/datain;             mkdir -p ${DATAIN}
DATAOUT=${DIRHOMED}/dataout;           mkdir -p ${DATAOUT}
SOURCES=${DIRHOMES}/sources;           mkdir -p ${SOURCES}
EXECS=${DIRHOMED}/execs;               mkdir -p ${EXECS}
#----------------------------------------------------------------------



# Local variables--------------------------------------
# Calculating CIs and final forecast dates in model namelist format:
export yyyymmddi=${YYYYMMDDHHi:0:8}
export hhi=${YYYYMMDDHHi:8:2}
echo "data: "$YYYYMMDDHHi 
echo "Limite da Previsão "$FCST
echo "Data e hora " $yyyymmddi $hhi
yyyymmddhhf=$(date +"%Y%m%d%H" -d "${yyyymmddi} ${hhi}:00 ${FCST} hours" )
final_date=${yyyymmddhhf:0:4}-${yyyymmddhhf:4:2}-${yyyymmddhhf:6:2}_${yyyymmddhhf:8:2}.00.00
#-------------------------------------------------------
# Untar the fixed files:
# x1.${RES}.graph.info.part.<Ncores> files can be found in datain/fixed
# *.TBL files also can be found in datain/fixed
# x1.${RES}.grid.nc also can be found in datain/fixed

echo -e  "${GREEN}==>${NC} copying and linking fixed input data... \n"
mkdir -p ${DATAIN}
rsync -rv --chmod=ugo=rw ${DIRDADOS}/MONAN_datain/datain/fixed ${DATAIN}
rsync -rv --chmod=ugo=rwx ${DIRDADOS}/MONAN_datain/execs ${DIRHOMED}
ln -sf ${DIRDADOS}/MONAN_datain/datain/WPS_GEOG ${DATAIN}

# Creating the x1.${RES}.static.nc file once, if does not exist yet:---------------
if [ ! -s ${DATAIN}/fixed/x1.${RES}.static.nc ]
then
   echo -e "${GREEN}==>${NC} Creating static.bash for submiting init_atmosphere to create x1.${RES}.static.nc...\n"
   time ./make_static.bash ${EXP} ${RES} ${YYYYMMDDHHi} ${FCST}
else
   echo -e "${GREEN}==>${NC} File x1.${RES}.static.nc already exist in ${DATAIN}/fixed.\n"
fi
#----------------------------------------------------------------------------------



# Degrib phase:---------------------------------------------------------------------
echo -e  "${GREEN}==>${NC} Submiting Degrib...\n"
time ./make_degrib.bash ${EXP} ${RES} ${YYYYMMDDHHi} ${FCST}
#----------------------------------------------------------------------------------



# Init Atmosphere phase:------------------------------------------------------------
echo -e  "${GREEN}==>${NC} Submiting Init Atmosphere...\n"
time ./make_initatmos.bash ${EXP} ${RES} ${YYYYMMDDHHi} ${FCST}
#----------------------------------------------------------------------------------




