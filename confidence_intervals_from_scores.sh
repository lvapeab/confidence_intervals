#!/bin/bash 

# Changelog:
# 22/06/2018 Álvaro Peris:
# - Compute statistical significance with paired-approximate randomization test.
# 17/01/2017 Álvaro Peris:
# - Added Meteor metric
# 18/11/2011 German Sanchis-Trilles:
# - output range with its appropriate precision (average and interval unchanged for informative reasons)
# 18/11/2011 Joan Albert Silvestre: 
# - Fixed bug concerning TER pairwise range
# - Fixed bug that caused the script to fail when -n < 1000
# - Added Brevity Penalty confidence interval
# - Added -Xmx flag to java -jar for memory efficiency
# 30/10/2009 German Sanchis-Trilles:
# - First version


help="\t\t17/01/2017 Á. Peris - 18/11/2011 J.A. Silvestre - 30/10/2009 G. Sanchis-Trilles                    \n
\n
Usage:\t confindence_intervals.sh <-t hypothesis> <-n nreps>                                  \n
\t__________________________[-b baseline] [-i interval] [-l lan] [-y] [-v] [-h]                              \n
\t This script will take up a reference file and a hypothesis file and compute TER and BLEU confidence       \n
\t intervals by means of bootstrapping. Note: This script needs a *modified* version of TERCOM and           \n
\t multi-bleu.perl. These two modified versions are included into this script for simplicity purposes and    \n
\t unpacked on the fly. If [-b baseline] is specified, pairwise improvement intervals will also be computed. \n
Input:\t -b baseline: file containing the baseline translations. If specified, pair                          \n
\t       -t hypothesis: file containing the (machine) translations to be evaluated.                          \n
\t       -n nreps: number of repetitions to do via bootstrapping.                                            \n
\t       -i interval: confidence interval to compute (default 95)                                            \n
\t       -y: do not delete temporary files.                                                                  \n
\t       -l: language (required for Meteor. (default en)                                                    \n                                                                                                    
\t       -v: activate verbose mode (set -x).                                                                 \n
\t       -h: show this help and exit.                                                                        \n
Output:  - confidence interval"

perl=$(which perl)
java=$(which java)
if [ "$(which gawk)" != "" ]; then AWK=$(which gawk); else AWK=$(which awk); fi
interval=95
lan=en
me=${BASH_SOURCE[0]}
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

nmoptions=$(cat ${me} | ${AWK} '/^exit$/{exit}{print $0}' | grep "++moptions" | wc -l | gawk '{ print $1-1 }')
moptions=0;
cmd=("$@")
for ((i=0;i<${#cmd[@]};i++)); do
    case ${cmd[$i]} in
	"-b")		    bas=${cmd[$((++i))]};;
	"-t")		    trans=${cmd[$((++i))]};((++moptions));;
	"-n")		    nreps=${cmd[$((++i))]};((++moptions));;
	"-i")		    interval=${cmd[$((++i))]};;
	"-y")               deletetemp="false";;
        "-l")               lan=${cmd[$((++i))]};;
        "-v")               set -x;;
        *)                  echo -e ${help} | tr '_' ' '; exit;;
    esac
done

if [ ${moptions} -lt ${nmoptions} ]; then echo -e ${help} | tr '_' ' '; exit; fi

if [ "$(which tmpdir)" == "" ]; then 
	if [ -d $HOME/tmp ]; then TMPPREF="$HOME/tmp";
	else TMPPREF="/tmp"; fi
else TMPPREF=$(tmpdir); fi
tmpdir=`mktemp -d ${TMPPREF}/conftmp.XXXXXXXXXXX`
if [ "${deletetemp}" == "" ]; then
    trap "rm -rf ${tmpdir}" EXIT;
else
    echo "Temporary directory created in $tmpdir"; echo "NOT deleting it!!";
    trap "echo 'Remember to delete temp!! Use:'; echo 'rm -rf '${tmpdir}" EXIT;
fi

echo "Reading raw scores from $trans..."

N=$(wc -l ${trans} | ${AWK} '{ print $1 }')

cat ${trans} > ${tmpdir}/scores 

if [ "$bas" != "" ]; then  # computing pairwise improvement

	echo -e "Reading baseline scores from $bas..."
	echo -e "baseline given: will compute pairwise improvement intervals as well!"
	cat ${bas} > ${tmpdir}/basscores
fi


${AWK} -v N=${nreps} -v interval=${interval} -v tmp=${tmpdir} -v size=${N} '
function precision (val) {
	pp=length(N)-3
	return int(val*(10**pp)+0.5)/(10**pp)
}{	if (ARGIND==1) scores[FNR]=$0
	if (ARGIND==2) basscores[FNR]=$0
} END {
	srand()
	printf "Computing confidence intervals with %d digits of precision...\n",length(N)-1
	for (n=1;n<=N;++n) {
		delete scoresacc; 
		if (ARGIND==2) { delete basscoresacc;  }
		for (i=1;i<=FNR;++i) {
			id=int(rand()*size+1)
			split(scores[id], tp)
			scoresacc[1]+=tp[1]; 
			if (ARGIND==2) {
				split(basscores[id], tp)
				basscoresacc[1]+=tp[1];
			}
	       	}
		scores[n]=scoresacc[1]/FNR
		if (ARGIND==2) { 
			basscores[n]=basscoresacc[1]
		}
		
	if (n%100==0) printf(".");
	}
	asort(scores);
	if (ARGIND==2) { asort(basscores);}

	for (i=1;i<=N;++i) printf("%s ", scores[i]) > tmp"/scores"

	print ""
	print "                                          [ from -- to ]    ( average +- interval )"
	print "Confidence intervals for candidate hypotheses:"
	rest=int(N*(100-interval)/200)
	lowerscore=scores[rest]*100;         upperscore=scores[N-rest]*100
	avgscore=(lowerscore+upperscore)/2;    terint=upperscore-avgscore

	printf "Scores   %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %1.4f ) \n",interval,precision(lowerscore),precision(upperscore),avgscore,scoreint

	if (ARGIND==2) {
		print ""
		print "Confidence intervals for baseline:"
	        lowerbasscore=basscore[rest]*100;         upperbasscore=basscore[N-rest]*100
	        avgbasscore=(lowerbasscore+upperbasscore)/2;    basterint=upperbasscore-avgbasscore

		printf "Scores    %2.1f%% confidence interval:       %2.4f -- %2.4f ( %2.4f +- %1.4f )\n",interval,precision(lowerbasscore),precision(upperbasscore),avgbasscore,basscoreint
	}
	}' ${tmpdir}/scores ${tmpdir}/basscores




if [ "$bas" != "" ]; then  # computing pairwise improvement
    echo "Computing statistical significance with approximate_randomization..."

    echo "Computing significance level"
    python ${DIR}/approximate_randomization_test.py ${tmpdir}/scores ${tmpdir}/basscores ${nreps}

fi

exit
