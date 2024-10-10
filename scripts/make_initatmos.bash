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
   echo "24 hour forcast example:"
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
EXECS=${JEDI_ROOT}/MPAS-Model;                mkdir -p ${EXECS}
#----------------------------------------------------------------------

echo "DATAOUT  : "${DATAOUT}
echo "EXECS   : "${EXECS}

# Local variables--------------------------------------
start_date=${YYYYMMDDHHi:0:4}-${YYYYMMDDHHi:4:2}-${YYYYMMDDHHi:6:2}_${YYYYMMDDHHi:8:2}:00:00
GEODATA=${DATAIN}/WPS_GEOG
cores=${INITATMOS_ncores}

DATEF=`date -u +%Y%m%d%H -d "${DYMD} ${HH} +${len} hours"`
OPERDIREXP=${GFSDATA}
BNDDIR=${OPERDIREXP}/${YYYYMMDDHHi:0:4}/${YYYYMMDDHHi:4:2}/${YYYYMMDDHHi:6:2}/${YYYYMMDDHHi:8:2}
#-------------------------------------------------------
mkdir -p ${DATAOUT}/${YYYYMMDDHHi}/Pre/logs


if [ ! -s ${DATAIN}/fixed/x1.${RES}.graph.info.part.${cores} ]
then
   if [ ! -s ${DATAIN}/fixed/x1.${RES}.graph.info ]
   then
      cd ${DATAIN}/fixed
      echo -e "${GREEN}==>${NC} downloading meshes tgz files ... \n"
      cd ${DATAIN}/fixed
      wget https://www2.mmm.ucar.edu/projects/mpas/atmosphere_meshes/x1.${RES}.tar.gz
      wget https://www2.mmm.ucar.edu/projects/mpas/atmosphere_meshes/x1.${RES}_static.tar.gz
      tar -xzvf x1.${RES}.tar.gz
      tar -xzvf x1.${RES}_static.tar.gz
   fi
   echo -e "${GREEN}==>${NC} Creating x1.${RES}.graph.info.part.${cores} ... \n"
   cd ${DATAIN}/fixed
   gpmetis -minconn -contig -niter=200 x1.${RES}.graph.info ${cores}
   rm -fr x1.${RES}.tar.gz x1.${RES}_static.tar.gz
fi


files_needed=("${DATAIN}/namelists/namelist.init_atmosphere.TEMPLATE" "${DATAIN}/namelists/streams.init_atmosphere.TEMPLATE" "${DATAIN}/fixed/x1.${RES}.graph.info.part.${cores}" "${DATAIN}/fixed/x1.${RES}.static.nc" "${DATAOUT}/${YYYYMMDDHHi}/Pre/${EXP}:${start_date:0:13}" "${EXECS}/init_atmosphere_model")
for file in "${files_needed[@]}"
do
  if [ ! -s "${file}" ]
  then
    echo -e  "\n${RED}==>${NC} ***** ATTENTION *****\n"	  
    echo -e  "${RED}==>${NC} [${0}] At least the file ${file} was not generated. \n"
    exit -1
  fi
done


sed -e "s,#LABELI#,${start_date},g;s,#GEODAT#,${GEODATA},g;s,#RES#,${RES},g" \
	 ${DATAIN}/namelists/namelist.init_atmosphere.TEMPLATE > ${SCRIPTS}/namelist.init_atmosphere

sed -e "s,#RES#,${RES},g" \
    ${DATAIN}/namelists/streams.init_atmosphere.TEMPLATE > ${SCRIPTS}/streams.init_atmosphere


ln -sf ${DATAIN}/fixed/x1.${RES}.graph.info.part.${cores} ${SCRIPTS}
ln -sf ${DATAIN}/fixed/x1.${RES}.static.nc ${SCRIPTS}
ln -sf ${DATAOUT}/${YYYYMMDDHHi}/Pre/${EXP}\:${start_date:0:13} ${SCRIPTS}
ln -sf ${EXECS}/init_atmosphere_model ${SCRIPTS}


rm -f ${SCRIPTS}/initatmos.bash 
cat << EOF0 > ${SCRIPTS}/initatmos.bash 
#!/bin/bash
#SBATCH --job-name=${INITATMOS_jobname}
#SBATCH --nodes=${INITATMOS_nnodes}                         # depends on how many boundary files are available
#SBATCH --partition=${INITATMOS_QUEUE} 
#SBATCH --tasks-per-node=${INITATMOS_ncores}               # only for benchmark
#SBATCH --time=${STATIC_walltime}
#SBATCH --output=${DATAOUT}/${YYYYMMDDHHi}/Pre/logs/initatmos.bash.o%j    # File name for standard output
#SBATCH --error=${DATAOUT}/${YYYYMMDDHHi}/Pre/logs/initatmos.bash.e%j     # File name for standard error output
#SBATCH --exclusive
##SBATCH --mem=500000

export executable=init_atmosphere_model
# ---------------------------------------------------------------------------
#  Open read and listing permition for other 
umask 0022    #  drwxr-xr-x  for new directories ;  -rw-r--r--  for new files
#----------------------------------------------------------------------------
ulimit -c unlimited
ulimit -v unlimited
ulimit -s unlimited

NTasks="\${SLURM_NTASKS:-64}"

source $(pwd)/setenv.bash
echo $JEDI_ROOT
module list
source ${JEDI_ROOT}/intel_env_mpas_v8.2 

cd ${SCRIPTS}
pwd

date
# time mpirun -np \${NTasks} -env UCX_NET_DEVICES=mlx5_0:1 -genvall ./\${executable}
time mpirun -np \${NTasks} ./\${executable}

date


mv ${SCRIPTS}/log.init_atmosphere.0000.out ${DATAOUT}/${YYYYMMDDHHi}/Pre/logs/log.init_atmosphere.0000.x1.${RES}.init.nc.${YYYYMMDDHHi}.out
mv namelist.init_atmosphere ${DATAOUT}/${YYYYMMDDHHi}/Pre/logs
mv streams.init_atmosphere ${DATAOUT}/${YYYYMMDDHHi}/Pre/logs
mv ${SCRIPTS}/x1.${RES}.init.nc ${DATAOUT}/${YYYYMMDDHHi}/Pre

chmod a+x ${DATAOUT}/${YYYYMMDDHHi}/Pre/x1.${RES}.init.nc 
rm -f ${SCRIPTS}/${EXP}\:${start_date:0:13}
rm -f ${SCRIPTS}/init_atmosphere_model
rm -f ${SCRIPTS}/x1.${RES}.graph.info.part.${cores}
rm -f ${SCRIPTS}/x1.${RES}.static.nc
rm -f ${SCRIPTS}/log.init_atmosphere.*.err

EOF0
chmod a+x ${SCRIPTS}/initatmos.bash

echo -e  "${GREEN}==>${NC} Executing sbatch initatmos.bash...\n"
cd ${SCRIPTS}
sbatch --wait ${SCRIPTS}/initatmos.bash
mv ${SCRIPTS}/initatmos.bash ${DATAOUT}/${YYYYMMDDHHi}/Pre/logs

if [ ! -s ${DATAOUT}/${YYYYMMDDHHi}/Pre/x1.${RES}.init.nc ]
then
  echo -e  "\n${RED}==>${NC} ***** ATTENTION *****\n"	
  echo -e  "${RED}==>${NC} Init Atmosphere phase fails! Check logs at ${DATAOUT}/logs/initatmos.* .\n"
  echo -e  "${RED}==>${NC} Exiting script. \n"
  exit -1
fi

