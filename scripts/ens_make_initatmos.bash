#!/bin/bash 

# -----------------------------------------------------
# create links needed for running MPAS init_atmosphere_model 
links_4_init () {

   degrib_fnm=$1
   prefix_dgrb=$2
   files_needed=("${DATAIN}/namelists/namelist.init_atmosphere.TEMPLATE" "${DATAIN}/namelists/streams.init_atmosphere.TEMPLATE" "${DATAIN}/fixed/x1.${RES}.graph.info.part.${cores}" "${DATAIN}/fixed/x1.${RES}.static.nc" "${DATAOUT}/${YYYYMMDDHHi}/Pre/${degrib_fnm}" "${EXECS}/init_atmosphere_model")
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
   #
   ## Once eache ensemble member runs in it onw $SCRIPTS dir, makes it generic by using link to GFS:yyyymmddhh 
   ## and avoids to change config_met_prefix in the namelist.init_atmosphere
   ln -sf ${DATAOUT}/${YYYYMMDDHHi}/Pre/${prefix_dgrb}\:${start_date:0:13} ${SCRIPTS}/GFS\:${start_date:0:13}   
   ln -sf ${EXECS}/init_atmosphere_model ${SCRIPTS}
}
# --------------------/\ links_4_init /\----------------------
#  Create the batch script to run init_atmosphere_model and run it 
mk_initatmos () {

  scpt=$1
  jobname=$2
  gribfname=$3
  prefix_dgrb=$4

rm -f ${SCRIPTS}/${scpt} 

cat << EOF0 > ${SCRIPTS}/${scpt}
#!/bin/bash
#SBATCH --job-name=${jobname}
#SBATCH --nodes=${INITATMOS_nnodes}                         # depends on how many boundary files are available
#SBATCH --partition=${INITATMOS_QUEUE} 
#SBATCH --tasks-per-node=${INITATMOS_ncores}               # only for benchmark
#SBATCH --time=${STATIC_walltime}
#SBATCH --output=${DATAOUT}/${YYYYMMDDHHi}/Pre/logs/${jobname}.o%j    # File name for standard output
#SBATCH --error=${DATAOUT}/${YYYYMMDDHHi}/Pre/logs/${jobname}.e%j     # File name for standard error output
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


mv ${SCRIPTS}/log.init_atmosphere.0000.out ${DATAOUT}/${YYYYMMDDHHi}/Pre/logs/log.init_atmosphere.0000.${prefix_dgrb}.${YYYYMMDDHHi}.out
mv namelist.init_atmosphere ${DATAOUT}/${YYYYMMDDHHi}/Pre/logs/namelist.init_atmosphere-${prefix_dgrb}
mv streams.init_atmosphere ${DATAOUT}/${YYYYMMDDHHi}/Pre/logs
mv ${SCRIPTS}/x1.${RES}.init.nc ${DATAOUT}/${YYYYMMDDHHi}/Pre/${prefix_dgrb}_x1.${RES}.init.nc

chmod a+x ${DATAOUT}/${YYYYMMDDHHi}/Pre/${prefix_dgrb}_x1.${RES}.init.nc 
rm -f ${SCRIPTS}/${EXP}\:${start_date:0:13}
rm -f ${SCRIPTS}/init_atmosphere_model
rm -f ${SCRIPTS}/x1.${RES}.graph.info.part.${cores}
rm -f ${SCRIPTS}/x1.${RES}.static.nc
rm -f ${SCRIPTS}/log.init_atmosphere.*.err

EOF0

  chmod a+x ${SCRIPTS}/${scpt}
  
  echo -e  "${GREEN}==>${NC} Executing sbatch ${scpt}...\n"
  cd ${SCRIPTS}
  sbatch --wait ${SCRIPTS}/${scpt}
  mv ${SCRIPTS}/${scpt} ${DATAOUT}/${YYYYMMDDHHi}/Pre/logs
  
}
# ----------------------------/\ mk_initatmos /\------------------------------------
# ------------------------------------------------------
verify_run () {
files_run=$1     
for file in "${files_run[@]}"
   do
     ls -1  ${DATAOUT}/${YYYYMMDDHHi}/Pre/${file}
     if [ ! -s ${DATAOUT}/${YYYYMMDDHHi}/Pre/${file} ] 
     then
       echo -e  "\n${RED}==>${NC} ***** ATTENTION *****\n"	  
       echo -e  "${RED}==>${NC} Init Atmosphere phase fails! At least the file ${file} was not generated at ${DATAIN}/${YYYYMMDDHHi}. \n"
       echo -e  "${RED}==>${NC} Check logs at ${DATAOUT}/logs/initatmos.* .\n"
       echo -e  "${RED}==>${NC} Exiting script. \n"
       exit -1
     fi
   done
}
# -------------/\ verify_run /\-------------------------
#############   MAIN ##############
if [ $# -lt 4 ]
then
   echo ""
   echo "Instructions: execute the command below"
   echo ""
   echo "${0} EXP_NAME RESOLUTION LABELI FCST"
   echo ""
   echo "EXP_NAME    :: Forcing: GFS or GFSENS"
   echo "            :: Others options to be added later..."
   echo "RESOLUTION  :: number of points in resolution model grid, e.g: 1024002  (24 km)"
   echo "LABELI      :: Initial date YYYYMMDDHH, e.g.: 2024010100"
   echo "FCST        :: Forecast hours, e.g.: 24 or 36, etc."
   echo "Esize       :: Number of member of ensemble, e.g. 80 ."
   echo ""
   echo "24 hour forecast example:"
   echo "${0} GFSENS 1024002 2024010100 24"
   echo "12 hour forecast example for 48 km grid cell:"
   echo "${0} GFSENS  256002 2024090100 12 80"
   echo ""

   exit
fi
# ---------------------------------------------------------------------------
#  Open read and listing permition for other 
umask 0022    #  drwxr-xr-x  for new directories ;  -rw-r--r--  for new files
#----------------------------------------------------------------------------

# Input variables:--------------------------------------
EXP=${1};         # EXP=GFS or EXP GFSENS
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

if [[ $# -eq 5 ]] ; then
  echo 'setenv.bash ensemble size ='$EnsSize' , changing to the command line argument : '$5
  EnsSize=$5
fi

## EnsSize=80 # defined by setenv.bash

# Standart directories variables:---------------------------------------
DIRHOMES=${DIR_SCRIPTS};                mkdir -p ${DIRHOMES}  
DIRHOMED=${DIR_DADOS};                  mkdir -p ${DIRHOMED}  
DATAIN=${DIRHOMED}/datain;              mkdir -p ${DATAIN}
DATAOUT=${DIRHOMED}/dataout;            mkdir -p ${DATAOUT}
SOURCES=${DIRHOMES}/sources;            mkdir -p ${SOURCES}
EXECS=${JEDI_ROOT}/MPAS-Model;                mkdir -p ${EXECS}
#----------------------------------------------------------------------

echo "DATAOUT  : "${DATAOUT}
echo "EXECS   : "${EXECS}

# Local variables--------------------------------------
start_date=${YY}-${MM}-${DD}_${HH}:00:00
GEODATA=${DATAIN}/WPS_GEOG
cores=${INITATMOS_ncores}

DATEF=`date -u +%Y%m%d%H -d "${DYMD} ${HH} +${len} hours"`
case $EXP in
  GFSENS) 
      OPERDIREXP=${GEFSDATA}
  ;;
  GFS)
      OPERDIREXP=${GFSDATA}
  ;;
esac

BNDDIR=${OPERDIREXP}/${YY}/${MM}/${DD}/${HH}
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

case $EXP in
  GFSENS) 
    for ensN in $(eval echo "{01..$EnsSize}"); do 
      SCRIPTS=${DIRHOMES}/scripts/${DYMD}${HH}/e${ensN};   mkdir -p ${SCRIPTS}

      prfix_dgrb=GEFS_${ensN}
      degrib_fname=${prfix_dgrb}:${start_date:0:13}

      links_4_init ${degrib_fname} ${prfix_dgrb}

      scrpt_nm='e'${ensN}'initatmos.bash'

      jobnm='e'${ensN}'init'
    
      rm -f ${SCRIPTS}/${scrpt_nm} 

      mk_initatmos ${scrpt_nm} ${jobnm} ${degrib_fname} ${prfix_dgrb}

      echo "Working directory: "$PWD
      files_init=("${prfix_dgrb}_x1.${RES}.init.nc")
      verify_run $files_init
    done
  ;;
  GFS)
    SCRIPTS=${DIRHOMES}/scripts/${DYMD}${HH};            mkdir -p ${SCRIPTS}

    prfix_dgrb=GFS
    degrib_fname=${prfix_dgrb}:${start_date:0:13}

    links_4_init ${degrib_fname} ${prfix_dgrb}

    scrpt_nm='initatmos.bash'

    jobnm='init'

    rm -f ${SCRIPTS}/${scrpt_nm} 

    mk_initatmos ${scrpt_nm} ${jobnm} ${degrib_fname} ${prfix_dgrb}

    echo "Working directory: "$PWD
    files_init=("${prfix_dgrb}_x1.${RES}.init.nc")
    verify_run $files_init
  ;;
esac

