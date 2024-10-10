#!/bin/bash 

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
   echo "LABELI      :: Initial date YYYYMMDDHH, e.g.: 2024010100"
   echo "FCST        :: Forecast hours, e.g.: 24 or 36, etc."
   echo ""
   echo "24 hour forecast example:"
   echo "${0} GFS 1024002 2024010100 24"
   echo "48 hour forecast example for 48 km grid cell:"
   echo "${0} GFS  256002 2024090100 48"
   echo ""

   exit
fi
# ---------------------------------------------------------------------------
#  Open read and listing permition for other 
umask 0022    #  drwxr-xr-x  for new directories ;  -rw-r--r--  for new files
#----------------------------------------------------------------------------

# Input variables:--------------------------------------
EXP=${1};         #EXP=GFS
RES=${2};         #RES=1024002
YYYYMMDDHHi=${3}; #YYYYMMDDHHi=2024012000
FCST=${4};        #FCST=24
#-------------------------------------------------------
# Parameter for DA
len=3
#-------------------------------------------------------
DYMD=${YYYYMMDDHHi:0:8}  # YYYYMMDD
YY=${YYYYMMDDHHi:0:4}
MM=${YYYYMMDDHHi:4:2}
DD=${YYYYMMDDHHi:6:2}
HH=${YYYYMMDDHHi:8:2}

# Set environment variables exports:
echo ""
echo -e "\033[1;32m==>\033[0m Moduling environment for MONAN model...\n"
. setenv.bash

# Standart directories variables:---------------------------------------
DIRHOMES=${DIR_SCRIPTS};                mkdir -p ${DIRHOMES}  
DIRHOMED=${DIR_DADOS};                  mkdir -p ${DIRHOMED}  
SCRIPTS=${DIRHOMES}/scripts/${DYMD}${HH};            mkdir -p ${SCRIPTS}
DATAIN=${DIRHOMED}/datain;              mkdir -p ${DATAIN}
DATAOUT=${DIRHOMED}/dataout;            mkdir -p ${DATAOUT}
SOURCES=${DIRHOMES}/sources;            mkdir -p ${SOURCES}
EXECS=${DIRHOMED}/execs;                mkdir -p ${EXECS}
#----------------------------------------------------------------------

  echo "DATAIN   : "${DATAIN}
  echo "DATAOUT  : "${DATAOUT}
  echo "EXECS   : "${EXECS}
  echo "WPS_EXEC : "${WPS_EXEC}

# Local variables--------------------------------------
start_date=${YYYYMMDDHHi:0:4}-${YYYYMMDDHHi:4:2}-${YYYYMMDDHHi:6:2}_${YYYYMMDDHHi:8:2}:00:00

DATEF=`date -u +%Y%m%d%H -d "${DYMD} ${HH} +${len} hours"`
OPERDIREXP=${GFSDATA}
BNDDIR=${OPERDIREXP}/${YYYYMMDDHHi:0:4}/${YYYYMMDDHHi:4:2}/${YYYYMMDDHHi:6:2}/${YYYYMMDDHHi:8:2}
#-------------------------------------------------------
mkdir -p ${DATAIN}/${YYYYMMDDHHi}
mkdir -p ${DATAOUT}/${YYYYMMDDHHi}/Pre/logs

###  Loading WRF-WPS environment ---------------------
source setenv_WPS.sh

if [ ! -d ${BNDDIR} ]
then
   echo -e "${RED}==>${NC}Condicao de contorno inexistente !"
   echo -e "${RED}==>${NC}Check ${BNDDIR} ." 
   exit 1                     
fi

GFS_CI='gfs.0p25.'${DYMD}${HH}'.f000.grib2'

files_needed=("${DATAIN}/fixed/x1.${RES}.static.nc" "${DATAIN}/fixed/Vtable.${EXP}" "${WPS_EXEC}/ungrib.exe" "${BNDDIR}/${GFS_CI}")
for file in "${files_needed[@]}"
do
  if [ ! -s "${file}" ]
  then
    echo -e  "\n${RED}==>${NC} ***** ATTENTION *****\n"	  
    echo -e  "${RED}==>${NC} [${0}] At least the file ${file} was not generated. \n"
    exit -1
  fi
done

ln -sf ${DATAIN}/fixed/x1.${RES}.static.nc ${SCRIPTS}
ln -sf ${DATAIN}/fixed/Vtable.${EXP} ${SCRIPTS}/Vtable
ln -sf ${WPS_EXEC}/ungrib.exe ${SCRIPTS}/.
ln -sf ${WPS_EXEC}/setenv_WPS.sh ${SCRIPTS}/.
ln -sf ${WPS_EXEC}/link_grib.csh ${SCRIPTS}/.
GFS_files='gfs.0p25.'${DYMD}${HH}'.f00*.grib2'
ln -sf ${BNDDIR}/$GFS_files ${DATAIN}/${YYYYMMDDHHi}/


# rm -f ${SCRIPTS}/degrib.bash 
cat << EOF0 > ${SCRIPTS}/degrib.bash 
#!/bin/bash
#SBATCH --job-name=${DEGRIB_jobname}
#SBATCH --nodes=${DEGRIB_nnodes}
#SBATCH --partition=${DEGRIB_QUEUE}
#SBATCH --ntasks=${DEGRIB_ncores}             
#SBATCH --tasks-per-node=${DEGRIB_ncpn}                     # ic for benchmark
#SBATCH --time=${STATIC_walltime}
#SBATCH --output=${DATAOUT}/${YYYYMMDDHHi}/Pre/logs/debrib.o%j    # File name for standard output
#SBATCH --error=${DATAOUT}/${YYYYMMDDHHi}/Pre/logs/debrib.e%j     # File name for standard error output
#
# ---------------------------------------------------------------------------
#  Open read and listing permition for other 
umask 0022    #  drwxr-xr-x  for new directories ;  -rw-r--r--  for new files
#----------------------------------------------------------------------------
ulimit -s unlimited
ulimit -c unlimited
ulimit -v unlimited

NTasks="\${SLURM_NTASKS:-1}"

export PMIX_MCA_gds=hash

source setenv_WPS.sh 

export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${HOME}/local/lib64
ldd ungrib.exe

cd ${SCRIPTS}


rm -f GRIBFILE.* namelist.wps


sed -e "s,#LABELI#,${start_date},g;s,#LABELF#,${start_date},g;s,#PREFIX#,GFS,g" \
	${DATAIN}/namelists/namelist.wps.TEMPLATE > ./namelist.wps

echo ./link_grib.csh ${GFSDATA}/${YY}/${MM}/${DD}/${HH}/gfs.0p25.${DYMD}${HH}.f*.grib2 
./link_grib.csh ${GFSDATA}/${YY}/${MM}/${DD}/${HH}/gfs.0p25.${DYMD}${HH}.f*.grib2 

date
time mpirun -np \${NTasks} ./ungrib.exe
date


grep "Successful completion of program ungrib.exe" ${SCRIPTS}/ungrib.log >& /dev/null

if [ \$? -ne 0 ]; then
   echo "  BUMMER: Ungrib generation failed for some yet unknown reason."
   echo " "
   tail -10 ${SCRIPTS}/ungrib.log
   echo " "
   exit 21
fi

mv GFS\:${start_date:0:13} ${DATAOUT}/${YYYYMMDDHHi}/Pre

#
# clean up and remove links
#
   mv ungrib.log ${DATAOUT}/${YYYYMMDDHHi}/Pre/logs/ungrib.${start_date}.log
   mv namelist.wps ${DATAOUT}/${YYYYMMDDHHi}/Pre/logs/namelist.${start_date}.wps

# Not need to remove, just symbolic links
  # rm -f ${SCRIPTS}/ungrib.exe 
  # rm -f ${SCRIPTS}/Vtable 
  # rm -f ${SCRIPTS}/x1.${RES}.static.nc
  # rm -f ${SCRIPTS}/GRIBFILE.AAA

echo "End of degrib Job"

EOF0

chmod a+x ${SCRIPTS}/degrib.bash

echo -e  "${GREEN}==>${NC} Executing sbatch degrib.bash...\n"
cd ${SCRIPTS}
## for debug
## ${SCRIPTS}/degrib.bash
sbatch --wait ${SCRIPTS}/degrib.bash
mv ${SCRIPTS}/degrib.bash ${DATAOUT}/${YYYYMMDDHHi}/Pre/logs

echo "Working directory: "`pwd`

files_ungrib=("${EXP}:${YYYYMMDDHHi:0:4}-${YYYYMMDDHHi:4:2}-${YYYYMMDDHHi:6:2}_${YYYYMMDDHHi:8:2}")
for file in "${files_ungrib[@]}"
do
  ls -1  ${DATAOUT}/${YYYYMMDDHHi}/Pre/${file}
  if [ ! -s ${DATAOUT}/${YYYYMMDDHHi}/Pre/${file} ] 
  then
    echo -e  "\n${RED}==>${NC} ***** ATTENTION *****\n"	  
    echo -e  "${RED}==>${NC} Degrib fails! At least the file ${file} was not generated at ${DATAIN}/${YYYYMMDDHHi}. \n"
    echo -e  "${RED}==>${NC} Check logs at ${DATAOUT}/logs/debrib.* .\n"
    echo -e  "${RED}==>${NC} Exiting script. \n"
    exit -1
  fi
done

