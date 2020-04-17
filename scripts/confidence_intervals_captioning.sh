#!/bin/bash 

# Changelog:

# 10/3/2015 Álvaro Peris Abril:
# - Adapted for taking m and MAR
# 18/11/2011 German Sanchis-Trilles:
# - output range with its appropriate precision (average and interval unchanged for informative reasons)
# 18/11/2011 Joan Albert Silvestre: 
# - Fixed bug concerning TER pairwise range
# - Fixed bug that caused the script to fail when -n < 1000
# - Added Brevity Penalty confidence interval
# - Added -Xmx flag to java -jar for memory efficiency
# 30/10/2009 German Sanchis-Trilles:
# - First version


help="\t\t 10/3/2015 Álvaro Peris - 18/11/2011 J.A. Silvestre - 30/10/2009 G. Sanchis-Trilles                                          \n
\n
Usage:\t confindence_intervals.sh <-t scores> <-n nreps>                                                     \n
\t__________________________[-b baseline] [-i interval] [-y] [-v] [-h]                                       \n
\t This script will take up a m and MAR scores file and compute MAR and m confidence                     \n
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


cat $trans > $tmpdir/scrcounts

if [ "$bas" != "" ]; then  # computing pairwise improvement

	echo -e "Reading baseline translations from $bas..."
	echo -e "baseline given: will compute pairwise improvement intervals as well!"
	cat $bas > $tmpdir/scr_bas
	bascrcnts=$tmpdir/scr_bas

fi

$AWK -v N=$nreps -v interval=$interval -v tmp=$tmpdir -v size=$N '
function precision (val) {
#	pp=int(log(N/100)/log(10))   # --> this is buggy... for N=1000 returns pp=2!!
	pp=length(N)-3
	return int(val*(10**pp)+0.5)/(10**pp)
}{
	if (ARGIND==1) scrcounts[FNR]=$0
	if (ARGIND==2) bascrcnts[FNR]=$0
} END {
	srand()
	printf "Computing confidence intervals with %d digits of precision...\n",length(N)-1
	for (n=1;n<=N;++n) {
		delete scrcountacc
		if (ARGIND==2) { delete basscrcountacc }
		for (i=1;i<=FNR;++i) {
			id=int(rand()*size+1)
			split(scrcounts[id], tp)
			scrcountacc[1]+=tp[1]; scrcountacc[2]+=tp[2]; scrcountacc[3]+=tp[3]; scrcountacc[4]+=tp[4]; scrcountacc[5]+=tp[5]; scrcountacc[6]+=tp[6]; scrcountacc[7]+=tp[7];
			if (ARGIND==2) {
				split(bascrcnts[id], tp)
            			basscrcountacc[1]+=tp[1]; basscrcountacc[2]+=tp[2]; basscrcountacc[3]+=tp[3]; basscrcountacc[4]+=tp[4]; basscrcountacc[5]+=tp[5]; basscrcountacc[6]+=tp[6]; basscrcountacc[7]+=tp[7];
			}
		}
		b1[n]=scrcountacc[1]/FNR
		b2[n]=scrcountacc[2]/FNR
		b3[n]=scrcountacc[3]/FNR
		b4[n]=scrcountacc[4]/FNR
		 m[n]=scrcountacc[5]/FNR
		 r[n]=scrcountacc[6]/FNR
		 c[n]=scrcountacc[7]/FNR

		if (ARGIND==2) { 
			basb1[n]=basscrcountacc[1]/FNR
			basb2[n]=basscrcountacc[2]/FNR
			basb3[n]=basscrcountacc[3]/FNR
			basb4[n]=basscrcountacc[4]/FNR
			basm[n]=basscrcountacc[5]/FNR
			basr[n]=basscrcountacc[6]/FNR
			basc[n]=basscrcountacc[7]/FNR
			
			b1diffs[n]=b1[n]-basb1[n]
			b2diffs[n]=b2[n]-basb2[n]
			b3diffs[n]=b3[n]-basb3[n]
			b4diffs[n]=b4[n]-basb4[n]
			mdiffs[n]=m[n]-basm[n]
			rdiffs[n]=r[n]-basr[n]
			cdiffs[n]=c[n]-basc[n]
			}
	if (n%100==0) printf(".");
	}
	asort(b1);
	asort(b2);
	asort(b3);
	asort(b4);
 	asort(m);
 	asort(r);
 	asort(c);
	if (ARGIND==2)
	{
		asort(basb1);
		asort(basb2);
		asort(basb3);
		asort(basb4);
 		asort(basm);
 		asort(basr); 
 		asort(basc); 
 	}

	for (i=1;i<=N;++i) printf("%s ", b1[i]) > tmp"/b1"
	for (i=1;i<=N;++i) printf("%s ", b2[i]) > tmp"/b2"
	for (i=1;i<=N;++i) printf("%s ", b3[i]) > tmp"/b3"
	for (i=1;i<=N;++i) printf("%s ", b4[i]) > tmp"/b4"
	for (i=1;i<=N;++i) printf("%s ", m[i]) > tmp"/m"
	for (i=1;i<=N;++i) printf("%s ", r[i]) > tmp"/r"
	for (i=1;i<=N;++i) printf("%s ", c[i]) > tmp"/c"
	

	print ""
	print "                                          [ from -- to ]    ( average +- interval )"
	print "Confidence intervals for candidate hypotheses:"
	rest=int(N*(100-interval)/200)
	
        lowerb1=b1[rest]*100;       upperb1=b1[N-rest]*100
	avgb1=(lowerb1+upperb1)/2; b1int=upperb1-avgb1 

        lowerb2=b2[rest]*100;       upperb2=b2[N-rest]*100
	avgb2=(lowerb2+upperb2)/2; b2int=upperb2-avgb2 
	
	        lowerb3=b3[rest]*100;       upperb3=b3[N-rest]*100
	avgb3=(lowerb3+upperb3)/2; b3int=upperb3-avgb3 
	

        lowerb4=b4[rest]*100;       upperb4=b4[N-rest]*100
	avgb4=(lowerb4+upperb4)/2; b4int=upperb4-avgb4 
	
	        lowerm=m[rest]*100;       upperm=m[N-rest]*100
	avgm=(lowerm+upperm)/2; mint=upperm-avgm 
	

        lowerr=r[rest]*100;       upperr=r[N-rest]*100
	avgr=(lowerr+upperr)/2; rint=upperr-avgr 
	
	        lowerc=c[rest]*100;       upperc=c[N-rest]*100
	avgc=(lowerc+upperc)/2; cint=upperc-avgc
	

	printf "BLEU-1  %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %1.4f )\n",interval,precision(lowerb1),precision(upperb1),avgb1,b1int
	printf "BLEU-2  %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %1.4f )\n",interval,precision(lowerb2),precision(upperb2),avgb2,b2int
	printf "BLEU-3  %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %1.4f )\n",interval,precision(lowerb3),precision(upperb3),avgb3,b3int
	printf "BLEU-4  %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %1.4f )\n",interval,precision(lowerb4),precision(upperb4),avgb4,b4int

	printf "METEOR  %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %1.4f )\n",interval,precision(lowerm),precision(upperm),avgm,mint
	printf "ROUGE   %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %1.4f )\n",interval,precision(lowerr),precision(upperr),avgr,rint
	printf "CIDEr   %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %1.4f )\n",interval,precision(lowerc),precision(upperc),avgc,cint

	if (ARGIND==2) {
		print ""
		print "Confidence intervals for baseline:"
	        lowerbasm=basm[rest]*100;       upperbasm=basm[N-rest]*100
	        avgbasm=(lowerbasm+upperbasm)/2; basmint=upperbasm-avgbasm
					
	        lowerbasmar=basmar[rest]*100;         upperbasmar=basmar[N-rest]*100
	        avgbasmar=(lowerbasmar+upperbasmar)/2;    basmarint=upperbasmar-avgbasmar
		printf "m  %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %1.4f )\n",interval,precision(lowerbasm),precision(upperbasm),avgbasm,basmint
		printf "MAR  %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %2.4f )\n",interval,precision(lowerbasmar),precision(upperbasmar),avgbasmar,basmarint

		print ""
		for (i=1;i<=N;++i) printf("%s ", mardiffs[i]) > tmp"/mardiffs"
		for (i=1;i<=N;++i) printf("%s ", mdiffs[i]) > tmp"/mdiffs"
		lowermdiff=mdiffs[rest]*100;               uppermdiff=mdiffs[N-rest]*100
		avgmdiff=(lowermdiff+uppermdiff)/2;     mintdiff=uppermdiff-avgmdiff

		lowermardiff=mardiffs[rest]*100;                 uppermardiff=mardiffs[N-rest]*100
		avgmardiff=(lowermardiff+uppermardiff)/2;        marintdiff=uppermardiff-avgmardiff
		printf "m  pairwise improvement %2.1f%% interval: % 2.4f -- % 2.4f ( % 2.4f +- % 1.4f )\n",interval,precision(lowermdiff),precision(uppermdiff),avgmdiff,mintdiff
		printf "MAR  pairwise improvement %2.1f%% interval: % 2.4f -- % 2.4f ( % 2.4f +- % 1.4f )\n",interval,precision(lowermardiff),precision(uppermardiff),avgmardiff,marintdiff

	}
}' $tmpdir/scrcounts $bascrcnts

exit
