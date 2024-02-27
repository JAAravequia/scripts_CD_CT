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
   echo ""

   exit
fi

# Set environment variables exports:
echo ""
echo -e "\033[1;32m==>\033[0m Moduling environment for MONAN model...\n"
. setenv.bash


# Standart directories variables:----------------------
DIRHOME=${DIRWORK}/../../MONAN;  mkdir -p ${DIRHOME}
SCRIPTS=${DIRHOME}/scripts;      mkdir -p ${SCRIPTS}
DATAIN=${DIRHOME}/datain;        mkdir -p ${DATAIN}
DATAOUT=${DIRHOME}/dataout;      mkdir -p ${DATAOUT}
SOURCES=${DIRHOME}/sources;      mkdir -p ${SOURCES}
EXECS=${DIRHOME}/execs;          mkdir -p ${EXECS}
#-------------------------------------------------------


# Input variables:--------------------------------------
EXP=${1};         #EXP=GFS
RES=${2};         #RES=1024002
YYYYMMDDHHi=${3}; #YYYYMMDDHHi=2024012000
FCST=${4};        #FCST=24
#-------------------------------------------------------


# Local variables--------------------------------------
start_date=${YYYYMMDDHHi:0:4}-${YYYYMMDDHHi:4:2}-${YYYYMMDDHHi:6:2}_${YYYYMMDDHHi:8:2}:00:00
GEODATA=${DATAIN}/WPS_GEOG
ncores=${INITATMOS_ncores}
#-------------------------------------------------------
cp -f setenv.bash ${SCRIPTS}
mkdir -p ${DATAOUT}/${YYYYMMDDHHi}/Pre/logs


sed -e "s,#LABELI#,${start_date},g;s,#GEODAT#,${GEODATA},g" \
	 ${DATAIN}/namelists/namelist.init_atmosphere.TEMPLATE > ${SCRIPTS}/namelist.init_atmosphere

cp ${DATAIN}/namelists/streams.init_atmosphere.TEMPLATE ${SCRIPTS}/streams.init_atmosphere
#CR: verificar se existe o arq *part.${ncores}. Caso nao exista, criar um script que gere o arq necessario
ln -sf ${DATAIN}/fixed/x1.${RES}.graph.info.part.${ncores} ${SCRIPTS}
ln -sf ${DATAIN}/fixed/x1.${RES}.static.nc ${SCRIPTS}
ln -sf ${DATAOUT}/${YYYYMMDDHHi}/Pre/GFS\:${start_date:0:13} ${SCRIPTS}
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

ulimit -c unlimited
ulimit -v unlimited
ulimit -s unlimited


. $(pwd)/setenv.bash

cd ${SCRIPTS}



date
time mpirun -np \${SLURM_NTASKS} -env UCX_NET_DEVICES=mlx5_0:1 -genvall ./\${executable}
date


mv ${SCRIPTS}/log.init_atmosphere.0000.out ${DATAOUT}/${YYYYMMDDHHi}/Pre/logs/log.init_atmosphere.0000.x1.${RES}.init.nc.${YYYYMMDDHHi}.out
mv namelist.init_atmosphere ${DATAOUT}/${YYYYMMDDHHi}/Pre/logs
mv streams.init_atmosphere ${DATAOUT}/${YYYYMMDDHHi}/Pre/logs
mv ${SCRIPTS}/x1.${RES}.init.nc ${DATAOUT}/${YYYYMMDDHHi}/Pre

chmod a+x ${DATAIN}/fixed//x1.${RES}.init.nc 
rm -f ${SCRIPTS}/GFS\:${start_date:0:13}
rm -f ${SCRIPTS}/init_atmosphere_model
rm -f ${SCRIPTS}/x1.1024002.graph.info.part.32
rm -f ${SCRIPTS}/x1.1024002.static.nc
rm -f ${SCRIPTS}/log.init_atmosphere.*.err

EOF0
chmod a+x ${SCRIPTS}/initatmos.bash

echo -e  "${GREEN}==>${NC} Executing sbatch initatmos.bash...\n"
cd ${SCRIPTS}
sbatch --wait ${SCRIPTS}/initatmos.bash

if [ ! -s ${DATAOUT}/${YYYYMMDDHHi}/Pre/x1.${RES}.init.nc ]
then
  echo -e  "\n${RED}==>${NC} ***** ATTENTION *****\n"	
  echo -e  "${RED}==>${NC} Init Atmosphere phase fails! Check logs at ${DATAOUT}/logs/initatmos.* .\n"
  echo -e  "${RED}==>${NC} Exiting script. \n"
  exit -1
fi
