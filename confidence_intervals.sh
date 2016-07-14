#!/bin/bash 

# Changelog:
# 18/11/2011 German Sanchis-Trilles:
# - output range with its appropriate precision (average and interval unchanged for informative reasons)
# 18/11/2011 Joan Albert Silvestre: 
# - Fixed bug concerning TER pairwise range
# - Fixed bug that caused the script to fail when -n < 1000
# - Added Brevity Penalty confidence interval
# - Added -Xmx flag to java -jar for memory efficiency
# 30/10/2009 German Sanchis-Trilles:
# - First version


help="\t\t18/11/2011 J.A. Silvestre - 30/10/2009 G. Sanchis-Trilles                                          \n
\n
Usage:\t confindence_intervals.sh <-r reference> <-t hypothesis> <-n nreps>                                  \n
\t__________________________[-b baseline] [-i interval] [-y] [-v] [-h]                                       \n
\t This script will take up a reference file and a hypothesis file and compute TER and BLEU confidence       \n
\t intervals by means of bootstrapping. Note: This script needs a *modified* version of TERCOM and           \n
\t multi-bleu.perl. These two modified versions are included into this script for simplicity purposes and    \n
\t unpacked on the fly. If [-b baseline] is specified, pairwise improvement intervals will also be computed. \n
Input:\t -r reference: file containing the reference translations.                                           \n
\t       -b baseline: file containing the baseline translations. If specified, pair                          \n
\t       -t hypothesis: file containing the (machine) translations to be evaluated.                          \n
\t       -n nreps: number of repetitions to do via bootstrapping.                                            \n
\t       -i interval: confidence interval to compute (default 95)                                            \n
\t       -y: do not delete temporary files.                                                                  \n
\t       -v: activate verbose mode (set -x).                                                                 \n
\t       -h: show this help and exit.                                                                        \n
Output:  - confidence interval"

perl=$(which perl)
java=$(which java)
if [ "$(which gawk)" != "" ]; then AWK=$(which gawk); else AWK=$(which awk); fi
interval=95

me=${BASH_SOURCE[0]}

nmoptions=$(cat $me | $AWK '/^exit$/{exit}{print $0}' | grep "++moptions" | wc -l | gawk '{ print $1-1 }')
moptions=0;
cmd=("$@")
for ((i=0;i<${#cmd[@]};i++)); do
    case ${cmd[$i]} in
	"-r") 		    ref=${cmd[$((++i))]};((++moptions));;
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

echo "Reading reference translations from $ref..."
echo "Reading hypotheses from $trans..."

N=$(wc -l $ref | $AWK '{ print $1 }')

mbleu=./sbs_mbleu.perl
#tercom=$tmpdir/sbs_tercom.jar
#tail -c $((4568+36336)) $me | head -c 4568 > $tmpdir/sbs_mbleu.perl
#tail -c 36336 $me > $tmpdir/sbs_tercom.jar

#mbleu=$HOME/bin/sbs_mbleu.perl
tercom=./sbs_tercom.jar

$perl $mbleu $ref < $trans 2>&1 | grep -v "^BLEU" > $tmpdir/bleucounts

cat $ref | $AWK '{ print $0,"(TER-"NR")" }' > $tmpdir/ter_ref
cat $trans | $AWK '{ print $0,"(TER-"NR")" }' > $tmpdir/ter_hyp
$java -Xmx512m -jar $tercom -r $tmpdir/ter_ref -h $tmpdir/ter_hyp  > $tmpdir/ter_res
cat $tmpdir/ter_res | grep "Sentence TER: "| cut -d ' ' -f 3,4 > $tmpdir/tercounts

if [ "$bas" != "" ]; then  # computing pairwise improvement

	echo -e "Reading baseline translations from $bas..."
	echo -e "baseline given: will compute pairwise improvement intervals as well!"
	$perl $mbleu $ref < $bas 2>&1 | grep -v "^BLEU" > $tmpdir/bleucounts_bas

	cat $bas | $AWK '{ print $0,"(TER-"NR")" }' > $tmpdir/ter_bas
	$java -Xmx512m -jar $tercom -r $tmpdir/ter_ref -h $tmpdir/ter_bas > $tmpdir/ter_res_bas
	cat $tmpdir/ter_res_bas | grep "Sentence TER: "| cut -d ' ' -f 3,4 > $tmpdir/tercounts_bas
	basbleucnts=$tmpdir/bleucounts_bas
	bastercnts=$tmpdir/tercounts_bas
fi

$AWK -v N=$nreps -v interval=$interval -v tmp=$tmpdir -v size=$N '
function precision (val) {
#	pp=int(log(N/100)/log(10))   # --> this is buggy... for N=1000 returns pp=2!!
	pp=length(N)-3
	return int(val*(10**pp)+0.5)/(10**pp)
}{
	if (ARGIND==1) bleucounts[FNR]=$0
	if (ARGIND==2) tercounts[FNR]=$0
	if (ARGIND==3) basbleucounts[FNR]=$0
	if (ARGIND==4) bastercounts[FNR]=$0
} END {
	srand()
	printf "Computing confidence intervals with %d digits of precision...\n",length(N)-1
	for (n=1;n<=N;++n) {
		delete tercountacc;    delete bleucountacc
		if (ARGIND==4) { delete bastercountacc; delete basbleucountacc }
		for (i=1;i<=FNR;++i) {
			id=int(rand()*size+1)
			split(tercounts[id], tp)
			tercountacc[1]+=tp[1]; tercountacc[2]+=tp[2]

			split(bleucounts[id], bp)
			for (j=1;j<=9;++j) bleucountacc[j]+=bp[j]

			if (ARGIND==4) {
				split(bastercounts[id], tp)
				bastercountacc[1]+=tp[1]; bastercountacc[2]+=tp[2]
				split(basbleucounts[id], bp)
				for (j=1;j<=9;++j) basbleucountacc[j]+=bp[j]
			}
		}
		ters[n]=tercountacc[1]/tercountacc[2]
		if (bleucountacc[9] > bleucountacc[5])
			brevpen=exp(1-bleucountacc[9]/bleucountacc[5])
		else brevpen=1

		brevpenalties[n]=brevpen

		bleus[n]=exp((  log(bleucountacc[1]/bleucountacc[5]) + \
				log(bleucountacc[2]/bleucountacc[6]) + \
				log(bleucountacc[3]/bleucountacc[7]) + \
				log(bleucountacc[4]/bleucountacc[8]))/4)*brevpen

		if (ARGIND==4) { 
			baster[n]=bastercountacc[1]/bastercountacc[2]
			if (basbleucountacc[9] > basbleucountacc[5])
				basbrevpen=exp(1-basbleucountacc[9]/basbleucountacc[5])
			else basbrevpen=1

			basbrevpenalties[n]=basbrevpen

			basbleu[n]=exp((  log(basbleucountacc[1]/basbleucountacc[5]) + \
				log(basbleucountacc[2]/basbleucountacc[6]) + \
				log(basbleucountacc[3]/basbleucountacc[7]) + \
				log(basbleucountacc[4]/basbleucountacc[8]))/4)*basbrevpen
			bleudiffs[n]=bleus[n]-basbleu[n]
			terdiffs[n]=ters[n]-baster[n]
			BPdiffs[n]=brevpenalties[n]-basbrevpenalties[n]
		}
	if (n%100==0) printf(".");
	}
	asort(bleus); asort(ters); asort(brevpenalties);
	if (ARGIND==4) { asort(basbleu); asort(baster); asort(basbrevpenalties); asort(terdiffs); asort(bleudiffs); asort(BPdiffs)}

	for (i=1;i<=N;++i) printf("%s ", ters[i]) > tmp"/ters"
	for (i=1;i<=N;++i) printf("%s ", bleus[i]) > tmp"/bleus"
	for (i=1;i<=N;++i) printf("%s ", brevpenalties[i]) > tmp"/BPs"

	print ""
	print "                                          [ from -- to ]    ( average +- interval )"
	print "Confidence intervals for candidate hypotheses:"
	rest=int(N*(100-interval)/200)
	lowerbleu=bleus[rest]*100;       upperbleu=bleus[N-rest]*100
	avgbleu=(lowerbleu+upperbleu)/2; bleuint=upperbleu-avgbleu
	lowerBP=brevpenalties[rest];       upperBP=brevpenalties[N-rest]
	avgBP=(lowerBP+upperBP)/2; BPint=upperBP-avgBP
	lowerter=ters[rest]*100;         upperter=ters[N-rest]*100
	avgter=(lowerter+upperter)/2;    terint=upperter-avgter
	printf "BLEU %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %1.4f )\n",interval,precision(lowerbleu),precision(upperbleu),avgbleu,bleuint
	printf "BP   %2.1f%% confidence interval:            %1.4f --  %1.4f (  %1.4f +- %1.4f )\n",interval,precision(lowerBP*100)/100,precision(upperBP*100)/100,avgBP,BPint
	printf "TER  %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %1.4f )\n",interval,precision(lowerter),precision(upperter),avgter,terint
#	print "BLEU "interval"% confidence interval:            " lowerbleu " -- " upperbleu " ( " avgbleu " +- " bleuint " )"
#	print "BP   "interval"% confidence interval:            " lowerBP " -- " upperBP " ( " avgBP " +- " BPint " )"
#	print "TER  "interval"% confidence interval:            " lowerter " -- " upperter " ( " avgter " +- " terint " )"

	if (ARGIND==4) {
		print ""
		print "Confidence intervals for baseline:"
	        lowerbasbleu=basbleu[rest]*100;       upperbasbleu=basbleu[N-rest]*100
	        avgbasbleu=(lowerbasbleu+upperbasbleu)/2; basbleuint=upperbasbleu-avgbasbleu
					lowerbasBP=basbrevpenalties[rest];       upperbasBP=basbrevpenalties[N-rest]
					avgbasBP=(lowerbasBP+upperbasBP)/2; basBPint=upperbasBP-avgbasBP
	        lowerbaster=baster[rest]*100;         upperbaster=baster[N-rest]*100
	        avgbaster=(lowerbaster+upperbaster)/2;    basterint=upperbaster-avgbaster
		printf "BLEU %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %1.4f )\n",interval,precision(lowerbasbleu),precision(upperbasbleu),avgbasbleu,basbleuint
		printf "BP   %2.1f%% confidence interval:            %1.4f --  %1.4f (  %1.4f +- %1.4f )\n",interval,precision(lowerBP*100)/100,precision(upperBP*100)/100,avgbasBP,basBPint
		printf "TER  %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %2.4f )\n",interval,precision(lowerbaster),precision(upperbaster),avgbaster,basterint

#	        print "BLEU "interval"% confidence interval:            " lowerbasbleu " -- " upperbasbleu " ( " avgbasbleu " +- " basbleuint " )"
#		print "BP   "interval"% confidence interval:            " lowerbasBP " -- " upperbasBP " ( " avgbasBP " +- " basBPint " )"
#	        print "TER  "interval"% confidence interval:            " lowerbaster " -- " upperbaster " ( " avgbaster " +- " basterint " )"
		


		print ""
		for (i=1;i<=N;++i) printf("%s ", terdiffs[i]) > tmp"/terdiffs"
		for (i=1;i<=N;++i) printf("%s ", bleudiffs[i]) > tmp"/bleudiffs"
		lowerbleudiff=bleudiffs[rest]*100;               upperbleudiff=bleudiffs[N-rest]*100
		avgbleudiff=(lowerbleudiff+upperbleudiff)/2;     bleuintdiff=upperbleudiff-avgbleudiff
		lowerBPdiff=BPdiffs[rest];               upperBPdiff=BPdiffs[N-rest]
		avgBPdiff=(lowerBPdiff+upperBPdiff)/2;     BPintdiff=upperBPdiff-avgBPdiff
		lowerterdiff=terdiffs[rest]*100;                 upperterdiff=terdiffs[N-rest]*100
		avgterdiff=(lowerterdiff+upperterdiff)/2;        terintdiff=upperterdiff-avgterdiff
		printf "BLEU pairwise improvement %2.1f%% interval: % 2.4f -- % 2.4f ( % 2.4f +- % 1.4f )\n",interval,precision(lowerbleudiff),precision(upperbleudiff),avgbleudiff,bleuintdiff
		printf "BP   pairwise improvement %2.1f%% interval: % 2.4f -- % 2.4f ( % 2.4f +- % 1.4f )\n",interval,precision(lowerBPdiff*100)/100,precision(upperBPdiff*100)/100,avgBPdiff,BPintdiff
		printf "TER  pairwise improvement %2.1f%% interval: % 2.4f -- % 2.4f ( % 2.4f +- % 1.4f )\n",interval,precision(lowerterdiff),precision(upperterdiff),avgterdiff,terintdiff
#		print "BLEU pairwise improvement "interval"% interval: " lowerbleudiff " -- " upperbleudiff " ( " avgbleudiff " +- " bleuintdiff " )"
#		print "BP   pairwise improvement "interval"% interval: " lowerBPdiff " -- " upperBPdiff " ( " avgBPdiff " +- " BPintdiff " )"
#		print "TER pairwise improvement  "interval"% interval: " lowerterdiff " -- " upperterdiff " ( " avgterdiff " +- " terintdiff " )"
	}
}' $tmpdir/bleucounts $tmpdir/tercounts $basbleucnts $bastercnts

exit
