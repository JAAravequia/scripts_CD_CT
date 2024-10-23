#!/bin/bash 
#-----------------------------------------------------------------------------#
# !SCRIPT: run_model
#
# !DESCRIPTION:
#     Script to run the MONAN model 
#     
#     Performs the following tasks:
# 
#        o VCheck all input files before 
#        o Creates the submition script
#        o Submit the model
#        o Veriffy all files generated
#        
#
#-----------------------------------------------------------------------------#

# -----------------------------------------------------
# create links needed for running MPAS init_atmosphere_model 
links_4_model () {
                    degrib_fnm=$1 ; prefix_run=$2

files_needed=("${DATAIN}/namelists/stream_list.atmosphere.output" "${DATAIN}/namelists/stream_list.atmosphere.diagnostics" "${DATAIN}/namelists/stream_list.atmosphere.surface" "${EXECS}/atmosphere_model" "${DATAIN}/fixed/x1.${RES}.static.nc" "${DATAIN}/fixed/x1.${RES}.graph.info.part.${cores}" "${DATAOUT}/${YYYYMMDDHHi}/Pre/${prefix_run}/x1.${RES}.init.nc" "${DATAIN}/fixed/Vtable.GFS")
for file in "${files_needed[@]}"
do
  if [ ! -s "${file}" ]
  then
    echo -e  "\n${RED}==>${NC} ***** ATTENTION *****\n"   
    echo -e  "${RED}==>${NC} [${0}] At least the file ${file} was not generated. \n"
    exit -1
  fi
done

ln -sf ${EXECS}/atmosphere_model ${SCRIPTS}/
ln -sf ${DATAIN}/fixed/*TBL ${SCRIPTS}/
ln -sf ${DATAIN}/fixed/*DBL ${SCRIPTS}/
ln -sf ${DATAIN}/fixed/*DATA ${SCRIPTS}/
ln -sf ${DATAIN}/fixed/x1.${RES}.static.nc ${SCRIPTS}/
ln -sf ${DATAIN}/fixed/x1.${RES}.graph.info.part.${cores} ${SCRIPTS}/

## prefix_run ="GEFS_NN_" , where NN is the number of ensemble. For deterministic GFS_run should be empty ""
 
ln -sf ${DATAOUT}/${YYYYMMDDHHi}/Pre/${prefix_run}/x1.${RES}.init.nc ${SCRIPTS}/x1.${RES}.init.nc
ln -sf ${DATAIN}/fixed/Vtable.${EXP} ${SCRIPTS}/   ## this is not needed for MPAS model run !!

## if GFS then
sed -e "s,#LABELI#,${start_date},g;s,#FCSTS#,${DD_HHMMSS_forecast},g;s,#RES#,${RES},g;
    s,#CONFIG_DT#,${CONFIG_DT},g;s,#CONFIG_LEN_DISP#,${CONFIG_LEN_DISP},g;s,#CONFIG_CONV_INTERVAL#,${CONFIG_CONV_INTERVAL},g" \
   ${DATAIN}/namelists/namelist.atmosphere.TEMPLATE > ${SCRIPTS}/namelist.atmosphere

echo sed -e "s,#RES#,${RES},g;s,#CIORIG#,${EXP},g;s,#LABELI#,${YYYYMMDDHHi},g;s,#NLEV#,${NLEV},g;s,#FGFREQ#,${OutInterval},g" \
   ${DATAIN}/namelists/streams.atmosphere.TEMPLATE > ${SCRIPTS}/streams.atmosphere

   sed -e "s,#RES#,${RES},g;s,#CIORIG#,${EXP},g;s,#LABELI#,${YYYYMMDDHHi},g;s,#NLEV#,${NLEV},g;s,#FGFREQ#,${OutInterval},g" \
   ${DATAIN}/namelists/streams.atmosphere.TEMPLATE > ${SCRIPTS}/streams.atmosphere
## fi
cp -f ${DATAIN}/namelists/stream_list.atmosphere.output ${SCRIPTS}/
cp -f ${DATAIN}/namelists/stream_list.atmosphere.diagnostics ${SCRIPTS}/
cp -f ${DATAIN}/namelists/stream_list.atmosphere.surface ${SCRIPTS}/
cp -f ${DATAIN}/namelists/stream_list.atmosphere.analysis ${SCRIPTS}/
cp -f ${DATAIN}/namelists/stream_list.atmosphere.background ${SCRIPTS}/
cp -f ${DATAIN}/namelists/stream_list.atmosphere.control ${SCRIPTS}/
cp -f ${DATAIN}/namelists/stream_list.atmosphere.ensemble ${SCRIPTS}/
 
}
# --------------------/\ links_4_init /\--------------------------

#  Create the batch script to run atmosphere_model and run it 
mk_run_model () {
                  scpt=$1 ; jobname=$2 ; init_fnm=$3 ; ens_pfix=$4

  rm -f ${SCRIPTS}/${scpt}

  mkdir -p ${DATAOUT}/${YYYYMMDDHHi}/$ens_pfix/logs
cat << EOF0 > ${SCRIPTS}/${scpt} 
#!/bin/bash
#SBATCH --job-name=${jobname}
#SBATCH --nodes=${MODEL_nnodes}
#SBATCH --ntasks=${MODEL_ncores}
#SBATCH --tasks-per-node=${MODEL_ncpn}
#SBATCH --partition=${MODEL_QUEUE}
#SBATCH --time=${MODEL_walltime}
#SBATCH --output=${DATAOUT}/${YYYYMMDDHHi}/${ens_pfix}/logs/${scpt}.o%j    # File name for standard output
#SBATCH --error=${DATAOUT}/${YYYYMMDDHHi}/${ens_pfix}/logs/${scpt}.e%j     # File name for standard error output
#SBATCH --exclusive
##SBATCH --mem=500000
# ---------------------------------------------------------------------------
#  Open read and listing permition for other 
umask 0022    #  drwxr-xr-x  for new directories ;  -rw-r--r--  for new files
#----------------------------------------------------------------------------

export executable=atmosphere_model

ulimit -c unlimited
ulimit -v unlimited
ulimit -s unlimited

NTasks="\${SLURM_NTASKS:-64}"

. $(pwd)/setenv.bash
source ${JEDI_ROOT}/intel_env_mpas_v8.2 

cd ${SCRIPTS}


date
# time mpirun -np \${NTasks} -env UCX_NET_DEVICES=mlx5_0:1 -genvall ./\${executable}
time mpirun -np \${NTasks} ./\${executable}

date

#
# move dataout, clean up and remove files/links
#
for bgname in bg.*
do 
   mv \${bgname} ${DATAOUT}/${YYYYMMDDHHi}/${ens_pfix}/${bgname} 
done

# mv MONAN_HIST_* ${DATAOUT}/${YYYYMMDDHHi}/Model
# cp ${EXECS}/VERSION.txt ${DATAOUT}/${YYYYMMDDHHi}/${ens_pfix}/.

mv log.atmosphere.*.out ${DATAOUT}/${YYYYMMDDHHi}/${ens_pfix}/logs
mv log.atmosphere.*.err ${DATAOUT}/${YYYYMMDDHHi}/${ens_pfix}/logs
mv namelist.atmosphere ${DATAOUT}/${YYYYMMDDHHi}/${ens_pfix}/logs
mv stream* ${DATAOUT}/${YYYYMMDDHHi}/${ens_pfix}/logs

# rm -f ${SCRIPTS}/atmosphere_model
# rm -f ${SCRIPTS}/*TBL 
# rm -f ${SCRIPTS}/*.DBL
# rm -f ${SCRIPTS}/*DATA
# rm -f ${SCRIPTS}/x1.${RES}.static.nc
# rm -f ${SCRIPTS}/x1.${RES}.graph.info.part.${cores}
# rm -f ${SCRIPTS}/Vtable.GFS
# rm -f ${SCRIPTS}/x1.${RES}.init.nc

EOF0

  chmod a+x ${SCRIPTS}/${scpt}

  echo -e  "${GREEN}==>${NC} Submitting MONAN atmosphere model and waiting for finish before exit... \n"
  echo -e  "${GREEN}==>${NC} Logs being generated at ${DATAOUT}/${YYYYMMDDHHi}/${ens_pfix}/logs ... \n"
  echo -e  "sbatch ${SCRIPTS}/${scpt}"
  sbatch ${WAIT_FLAG} ${SCRIPTS}/${scpt}
  mv ${SCRIPTS}/${scpt} ${DATAOUT}/${YYYYMMDDHHi}/${ens_pfix}/logs

}

# ----------------------------/\ mk_run_model /\------------------------------------
# ------------------------------------------------------
verify_run () {
                ens_pfix=$1

output_interval=${fgfreq}
for i in $(seq 0 ${output_interval} ${FCST})
do
   hh=${YYYYMMDDHHi:8:2}
   currentdate=$(date -u +"%Y-%m-%d_%H" -d "${YYYYMMDDHHi:0:8} ${hh}:00 ${i} hours")
   ## file=MONAN_DIAG_G_MOD_GFS_${YYYYMMDDHHi}_${currentdate}.00.00.x${RES}L55.nc
   file=bg.${currentdate}.00.00.nc    # bg.2024-09-03_00.00.00.nc
   
   if [ ! -s ${DATAOUT}/${YYYYMMDDHHi}/${ens_pfix}/${file} ]
   then
    echo -e  "\n${RED}==>${NC} ***** ATTENTION *****\n"	  
    echo -e  "${RED}==>${NC} [${0}] At least the file ${DATAOUT}/${YYYYMMDDHHi}/${ens_pfix}/${file} was not generated. \n"
    exit -1
  fi
      
done

}
# -------------/\ verify_run /\-------------------------

#  Given max number of simultaneous job (mx_jobs) and ensemble number (enumber) 
#  define if job should wait (TRUE) or not (FALSE) . 
#  jwait will be true each mx_jobs lauched 
job_wait () {
              enumber=$1 ;  mx_jobs=$2
              # input arguments
   echo -e "JOB Wait: $enumber $mx_jobs $ensN "
   div=$( echo "${enumber}/${mx_jobs}" | bc -l )
   rounddiv=$( printf '%.0f' $div )
   numint=$( echo "$rounddiv*$mx_jobs" | bc )
   if [[ $numint -eq $enumber ]]; then  
     jwait=true 
   else 
     jwait=false 
   fi
}
# -------------/\ job_wait /\-------------------------
#############   MAIN ##############
if [ $# -lt 4 ]
then
   echo ""
   echo "Instructions: execute the command below"
   echo ""
   echo "${0} [EXP_NAME/OP] RESOLUTION LABELI FCST [Esize]"
   echo ""
   echo "EXP_NAME    :: Forcing: GFSENS or GFS"
   echo "OP          :: clean: remove all temporary files createed in the last run."
   echo "RESOLUTION  :: number of points in resolution model grid, e.g: 1024002  (24 km)"
   echo "LABELI      :: Initial date YYYYMMDDHH, e.g.: 2024010100"
   echo "FG_interval :: Interval of forecast outputs, e.g., each 6 or 24 hours"  
   echo "FCST        :: Forecast hours, e.g.: 24 or 36, etc."
   echo "Esize       :: Optional: Number of member of ensemble, default is 80 ."
   echo ""
   echo "24 hour forecast example:"
   echo "${0} GFSENS 1024002 2024010100 24"
   echo "GFSENS @ 48 km grid cell, output each 6 hours upto 12 hour forecast example for 80 ensemble members:"
   echo "${0} GFSENS  256002 2024090100 6 12 80"
   echo "Cleannig temp files example:"
   echo "${0} clean"
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
export fgfreq=${4} 
FCST=${5};        #FCST=24
#-------------------------------------------------------
# Parameter for DA
max_jobs=4    # assuming we have 4 nodes for DA
len=3
## export fgfreq=6 ## Output each 24 hours for building B Matrix
bgts=$(($fgfreq*3600))
OutInterval=`date -d "@$bgts" -u "+%-H:%M:%S"`
# OutInterval='06:00:00'  ## interval to output first guess / forecasts
echo "I/O interval : "${OutInterval}

## exit ## debug
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

## EnsSize=80 # defined by setenv.bash
if [ $# -eq 1 ]
then
   op=$(echo "${1}" | tr '[A-Z]' '[a-z]')
   if [ ${op} = "clean" ]
   then
      clean_model_tmp_files
      exit
   else
      echo "Should type just \"clean\" for cleanning."
      echo "${0} clean"
      echo ""
      exit
   fi   
fi
if [[ $# -eq 6 ]] ; then
  echo 'setenv.bash ensemble size ='$EnsSize' , changing to the command line argument : '$6
  EnsSize=$6
fi


# Standart directories variables:---------------------------------------
DIRHOMES=${DIR_SCRIPTS};                mkdir -p ${DIRHOMES}  
DIRHOMED=${DIR_DADOS};                  mkdir -p ${DIRHOMED}  
DATAIN=${DIRHOMED}/datain;              mkdir -p ${DATAIN}
DATAOUT=${DIRHOMED}/dataout;            mkdir -p ${DATAOUT}
SOURCES=${DIRHOMES}/sources;            mkdir -p ${SOURCES}
EXECS=${JEDI_ROOT}/MPAS-Model;                mkdir -p ${EXECS}
#----------------------------------------------------------------------
MODEL_TBLs=${EXECS}/src/core_atmosphere/physics
#----------------------------------------------------------------------
echo "DATAOUT  : "${DATAOUT}
echo "EXECS   : "${EXECS}

# Local variables--------------------------------------
start_date=${YY}-${MM}-${DD}_${HH}:00:00
cores=${MODEL_ncores}
hhi=${HH}
NLEV=55

# Calculating default parameters for different resolutions
if [ $RES -eq 1024002 ]; then  #24Km
   CONFIG_DT=180.0
   CONFIG_LEN_DISP=24000.0
   CONFIG_CONV_INTERVAL="00:15:00"
elif [ $RES -eq 256002 ]; then  #48Km
   CONFIG_DT=240.0
   CONFIG_LEN_DISP=48000.0
   CONFIG_CONV_INTERVAL="00:10:00"
elif [ $RES -eq 40962 ]; then  #120Km
   CONFIG_DT=600.0
   CONFIG_LEN_DISP=120000.0
   CONFIG_CONV_INTERVAL="00:10:00"
fi
#-------------------------------------------------------

# Calculating forecast extension for model namelist in format: DD_HH:MM:SS 
# using: start_date(yyyymmdd) + FCST(hh) :
ind=$(printf "%02d\n" $(echo "${FCST}/24" | bc))
inh=$(printf "%02.0f\n" $(echo "((${FCST}/24)-${ind})*24" | bc -l))
DD_HHMMSS_forecast=$(echo "${ind}_${inh}:00:00")


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

      prfix_exp=${ensN}
      init_fname=${prfix_exp}x1.${RES}.init.nc

      links_4_model ${init_fname} ${prfix_exp}

      scrpt_nm='e'${ensN}'model.bash'

      jobnm='e'${ensN}'MPAS'
    
      rm -f ${SCRIPTS}/${scrpt_nm} 
            
      job_wait $ensN $max_jobs
      if [[ $jwait == true ]]; then 
         WAIT_FLAG='--wait'
      else
         WAIT_FLAG=''
      fi

      pfix_out=${ensN}        # add a prefix in the output of each ensemble bg file
      mk_run_model ${scrpt_nm} ${jobnm} ${init_fname} ${pfix_out}

      echo "Working directory: "$PWD
      if [[ $jwait == true ]]; then 
        verify_run $pfix_out 
      fi
    done
  ;;
  GFS)
    SCRIPTS=${DIRHOMES}/scripts/${DYMD}${HH};            mkdir -p ${SCRIPTS}

    prfix_dgrb=GFS
    init_fname=x1.${RES}.init.nc

    links_4_init ${init_fname} ${prfix_dgrb}

    scrpt_nm='initatmos.bash'

    jobnm='init'
    WAIT_FLAG='--wait'
    rm -f ${SCRIPTS}/${scrpt_nm} 
    pfix_out=''  # do not change the output names for deterministic run

    mk_run_model ${scrpt_nm} ${jobnm} ${init_fname} ${pfix_out}

    echo "Working directory: "$PWD
    
    verify_run ""
  ;;
esac





