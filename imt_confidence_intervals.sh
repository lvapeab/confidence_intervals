#!/bin/bash 

# Changelog:

# 30/11/2017 Álvaro Peris Abril:
# - Added KSMR
# 10/3/2015 Álvaro Peris Abril:
# - Adapted for taking WSR and MAR
# 18/11/2011 German Sanchis-Trilles:
# - output range with its appropriate precision (average and interval unchanged for informative reasons)
# 18/11/2011 Joan Albert Silvestre: 
# - Fixed bug concerning TER pairwise range
# - Fixed bug that caused the script to fail when -n < 1000
# - Added Brevity Penalty confidence interval
# - Added -Xmx flag to java -jar for memory efficiency
# 30/10/2009 German Sanchis-Trilles:
# - First version


help="\t\t 10/3/2015 Á. Peris - 18/11/2011 J.A. Silvestre - 30/10/2009 G. Sanchis-Trilles                    \n
\n
Usage:\t imt_confindence_intervals.sh <-t scores> <-n nreps>                                                 \n
\t__________________________[-b baseline] [-i interval] [-y] [-v] [-h]                                       \n
\t This script will take up a WSR and MAR scores file and compute MAR and WSR confidence                     \n
\t intervals by means of bootstrapping. If [-b baseline] is specified, pairwise improvement                  \n
\t intervals will also be computed. \n
Input:\t -b baseline: file containing the baseline scores. If specified, pair                                \n
\t       -t scores: file containing the scores to be evaluated.                                              \n
\t       -n nreps: number of repetitions to do via bootstrapping.                                            \n
\t       -i interval: confidence interval to compute (default 95)                                            \n
\t       -y: do not delete temporary files.                                                                  \n
\t       -v: activate verbose mode (set -x).                                                                 \n
\t       -h: show this help and exit.                                                                        \n
Output:  - confidence interval"

if [ "$(which gawk)" != "" ]; then AWK=$(which gawk); else AWK=$(which awk); fi
interval=95

me=${BASH_SOURCE[0]}

nmoptions=$(cat $me | $AWK '/^exit$/{exit}{print $0}' | grep "++moptions" | wc -l | gawk '{ print $1-1 }')
moptions=0;
cmd=("$@")
for ((i=0;i<${#cmd[@]};i++)); do
    case ${cmd[$i]} in
	"-b")		    bas=${cmd[$((++i))]};;
	"-t")		    trans=${cmd[$((++i))]};((++moptions));;
	"-n")		    nreps=${cmd[$((++i))]};((++moptions));;
	"-i")		    interval=${cmd[$((++i))]};;
	"-y")               deletetemp="false";;
        "-v")               set -x;;
        *)               echo -e $help | tr '_' ' '; exit;;
    esac
done

if [ $moptions -lt $nmoptions ]; then echo -e $help | tr '_' ' '; exit; fi

if [ "$(which tmpdir)" == "" ]; then 
	if [ -d $HOME/tmp ]; then TMPPREF="$HOME/tmp";
	else TMPPREF="/tmp"; fi
else TMPPREF=$(tmpdir); fi
tmpdir=`mktemp -d $TMPPREF/conftmp.XXXXXXXXXXX`
if [ "$deletetemp" == "" ]; then
    trap "rm -rf $tmpdir" EXIT;
else
    echo "Temporary directory created in $tmpdir"; echo "NOT deleting it!!";
    trap "echo 'Remember to delete temp!! Use:'; echo 'rm -rf '$tmpdir" EXIT;
fi

echo "Reading scores from $trans..."

N=$(wc -l $trans | $AWK '{ print $1 }')


cat $trans > $tmpdir/wsrcounts

if [ "$bas" != "" ]; then  # computing pairwise improvement

	echo -e "Reading baseline translations from $bas..."
	echo -e "baseline given: will compute pairwise improvement intervals as well!"
	cat $bas > $tmpdir/wsrcounts_bas
	baswsrcnts=$tmpdir/wsrcounts_bas

fi

$AWK -v N=$nreps -v interval=$interval -v tmp=$tmpdir -v size=$N '
function precision (val) {
#	pp=int(log(N/100)/log(10))   # --> this is buggy... for N=1000 returns pp=2!!
	pp=length(N)-3
	return int(val*(10**pp)+0.5)/(10**pp)
}{
	if (ARGIND==1) wsrcounts[FNR]=$0
	if (ARGIND==2) baswsrcounts[FNR]=$0
} END {
	srand()
	printf "Computing confidence intervals with %d digits of precision...\n",length(N)-1
	for (n=1;n<=N;++n) {
		delete wsrcountacc
		if (ARGIND==2) { delete baswsrcountacc }
		for (i=1;i<=FNR;++i) {
			id=int(rand()*size+1)
			split(wsrcounts[id], tp)
			wsrcountacc[1]+=tp[1]; 
                        wsrcountacc[2]+=tp[2];
                        wsrcountacc[3]+=tp[3];
			if (ARGIND==2) {
				split(baswsrcounts[id], tp)
				baswsrcountacc[1]+=tp[1]; 
                                baswsrcountacc[2]+=tp[2];
                                baswsrcountacc[3]+=tp[3];

			}
		}
		wsrs[n]=wsrcountacc[1]/FNR
                mars[n]=wsrcountacc[2]/FNR
                ksmrs[n]=wsrcountacc[3]/FNR


		if (ARGIND==2) { 
			baswsr[n]=baswsrcountacc[1]/FNR
                        basmar[n]=baswsrcountacc[2]/FNR 
                        basksmr[n]=baswsrcountacc[3]/FNR 
			wsrdiffs[n]=wsrs[n]-baswsr[n]
			mardiffs[n]=mars[n]-basmar[n]
			ksmrdiffs[n]=ksmrs[n]-basksmr[n]
			}
	if (n%100==0) printf(".");
	}
	asort(wsrs); asort(mars); asort(ksmrs);
	if (ARGIND==2) { asort(baswsr); asort(basmar); asort(basksmr); asort(wsrdiffs); asort(mardiffs); asort(ksmrdiffs)}

	for (i=1;i<=N;++i) printf("%s ", wsrs[i]) > tmp"/wsrs"
	for (i=1;i<=N;++i) printf("%s ", mars[i]) > tmp"/mars"
	for (i=1;i<=N;++i) printf("%s ", ksmrs[i]) > tmp"/ksmrs"


	print ""
	print "                                          [ from -- to ]    ( average +- interval )"
	print "Confidence intervals for candidate hypotheses:"
	rest=int(N*(100-interval)/200)
	
        lowerwsr=wsrs[rest]*100;       upperwsr=wsrs[N-rest]*100
	avgwsr=(lowerwsr+upperwsr)/2; wsrint=upperwsr-avgwsr
        lowermar=mars[rest]*100;         uppermar=mars[N-rest]*100
	avgmar=(lowermar+uppermar)/2;    marint=uppermar-avgmar
        lowerksmr=ksmrs[rest]*100;         upperksmr=ksmrs[N-rest]*100
	avgksmr=(lowerksmr+upperksmr)/2;    ksmrint=upperksmr-avgksmr

    sumsq_wsr=0
    sumsq_mar=0
    sumsq_ksmr=0
    for(i=1;i<=N;i++) {
          sumsq_wsr += (wsrs[i]*100 - avgwsr)^2
          sumsq_mar += (mars[i]*100 - avgmar)^2
          sumsq_ksmr += (ksmrs[i]*100 - avgksmr)^2
          }
          stdev_wsr=sqrt(sumsq_wsr/(N-1))
          stdev_mar=sqrt(sumsq_mar/(N-1))
          stdev_ksmr=sqrt(sumsq_ksmr/(N-1))


	printf "WSR   %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %1.4f ) - WSR  stdev: %1.4f \n",interval,precision(lowerwsr),precision(upperwsr),avgwsr,wsrint,stdev_wsr
	printf "MAR   %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %1.4f ) - MAR  stdev: %1.4f \n",interval,precision(lowermar),precision(uppermar),avgmar,marint,stdev_mar
	printf "KSMR  %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %1.4f ) - KSMR stdev: %1.4f \n",interval,precision(lowerksmr),precision(upperksmr),avgksmr,ksmrint,stdev_ksmr
#	print "WSR     "interval"% confidence interval:            " lowerwsr " -- " upperwsr " ( " avgwsr " +- " wsrint " )"
#	print "MAR     "interval"% confidence interval:            " lowermar " -- " uppermar " ( " avgmar " +- " marint " )"

	if (ARGIND==2) {
		print ""
		print "Confidence intervals for baseline:"
	        lowerbaswsr=baswsr[rest]*100;       upperbaswsr=baswsr[N-rest]*100
	        avgbaswsr=(lowerbaswsr+upperbaswsr)/2; baswsrint=upperbaswsr-avgbaswsr
					
	        lowerbasmar=basmar[rest]*100;         upperbasmar=basmar[N-rest]*100
	        avgbasmar=(lowerbasmar+upperbasmar)/2;    basmarint=upperbasmar-avgbasmar
				
	        lowerbasksmr=basksmr[rest]*100;         upperbasksmr=basksmr[N-rest]*100
	        avgbasksmr=(lowerbasksmr+upperbasksmr)/2;    basksmrint=upperbasksmr-avgbasksmr

		printf "WSR   %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %1.4f )\n",interval,precision(lowerbaswsr),precision(upperbaswsr),avgbaswsr,baswsrint
		printf "MAR   %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %2.4f )\n",interval,precision(lowerbasmar),precision(upperbasmar),avgbasmar,basmarint
		printf "KSMR  %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %2.4f )\n",interval,precision(lowerbasksmr),precision(upperbasksmr),avgbasksmr,basksmrint

		print ""
		for (i=1;i<=N;++i) printf("%s ", mardiffs[i]) > tmp"/mardiffs"
		for (i=1;i<=N;++i) printf("%s ", wsrdiffs[i]) > tmp"/wsrdiffs"
		for (i=1;i<=N;++i) printf("%s ", ksmrdiffs[i]) > tmp"/ksmrdiffs"
		lowerwsrdiff=wsrdiffs[rest]*100;               upperwsrdiff=wsrdiffs[N-rest]*100
		avgwsrdiff=(lowerwsrdiff+upperwsrdiff)/2;     wsrintdiff=upperwsrdiff-avgwsrdiff

		lowermardiff=mardiffs[rest]*100;                 uppermardiff=mardiffs[N-rest]*100
		avgmardiff=(lowermardiff+uppermardiff)/2;        marintdiff=uppermardiff-avgmardiff

		lowerksmrdiff=ksmrdiffs[rest]*100;                 upperksmrdiff=ksmrdiffs[N-rest]*100
		avgksmrdiff=(lowerksmrdiff+upperksmrdiff)/2;        ksmrintdiff=upperksmrdiff-avgksmrdiff

		printf "WSR   pairwise improvement %2.1f%% interval: % 2.4f -- % 2.4f ( % 2.4f +- % 1.4f )\n",interval,precision(lowerwsrdiff),precision(upperwsrdiff),avgwsrdiff,wsrintdiff
		printf "MAR   pairwise improvement %2.1f%% interval: % 2.4f -- % 2.4f ( % 2.4f +- % 1.4f )\n",interval,precision(lowermardiff),precision(uppermardiff),avgmardiff,marintdiff
		printf "KSRM  pairwise improvement %2.1f%% interval: % 2.4f -- % 2.4f ( % 2.4f +- % 1.4f )\n",interval,precision(lowerksmrdiff),precision(upperksmrdiff),avgksmrdiff,ksmrintdiff

	}
}' $tmpdir/wsrcounts $baswsrcnts 

exit
