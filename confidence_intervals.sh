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
Usage:\t confindence_intervals.sh <-r reference> <-t hypothesis> <-n nreps>                                  \n
\t__________________________[-b baseline] [-i interval] [-l lan] [-y] [-v] [-h]                              \n
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
	"-r") 		    ref=${cmd[$((++i))]};((++moptions));;
	"-b")		    bas=${cmd[$((++i))]};;
	"-t")		    trans=${cmd[$((++i))]};((++moptions));;
	"-n")		    nreps=${cmd[$((++i))]};((++moptions));;
	"-i")		    interval=${cmd[$((++i))]};;
	"-y")               deletetemp="false";;
        "-l")               lan=${cmd[$((++i))]};;
        "-v")               set -x;;
        *)               echo -e ${help} | tr '_' ' '; exit;;
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

echo "Reading reference translations from $ref..."
echo "Reading hypotheses from $trans..."

ref_escaped=${tmpdir}/`basename ${ref}`_escaped
trans_escaped=${tmpdir}/`basename ${trans}`_escaped

sed  's/#/\\#/g'< ${ref} > ${ref_escaped}
sed  's/#/\\#/g'< ${trans} > ${trans_escaped}



N=$(wc -l ${ref_escaped} | ${AWK} '{ print $1 }')

mbleu=${DIR}/sbs_mbleu.perl
#tercom=$tmpdir/sbs_tercom.jar
#tail -c $((4568+36336)) $me | head -c 4568 > $tmpdir/sbs_mbleu.perl
#tail -c 36336 $me > $tmpdir/sbs_tercom.jar

#mbleu=$HOME/bin/sbs_mbleu.perl
tercom=${DIR}/sbs_tercom.jar

meteorcom=${DIR}/meteor-*.jar

${perl} ${mbleu} ${ref_escaped} < ${trans_escaped} 2>&1 | grep -v "^BLEU" > ${tmpdir}/bleucounts

cat ${ref_escaped} | ${AWK} '{ print $0,"(TER-"NR")" }' > ${tmpdir}/ter_ref
cat ${trans_escaped} | ${AWK} '{ print $0,"(TER-"NR")" }' > ${tmpdir}/ter_hyp
${java} -Xmx512m -jar ${tercom} -r ${tmpdir}/ter_ref -h ${tmpdir}/ter_hyp  > ${tmpdir}/ter_res
cat ${tmpdir}/ter_res | grep "Sentence TER: "| cut -d ' ' -f 3,4 > ${tmpdir}/tercounts

${java} -Xmx512m -jar ${meteorcom} ${trans_escaped} ${ref_escaped} -l ${lan}  > ${tmpdir}/meteor_res
cat ${tmpdir}/meteor_res | grep "Segment"| ${AWK} 'BEGIN{FS="\t"}{print $2}' > ${tmpdir}/meteorcounts


if [ "$bas" != "" ]; then  # computing pairwise improvement

	echo -e "Reading baseline translations from $bas..."
	echo -e "baseline given: will compute pairwise improvement intervals as well!"
	bas_escaped=${tmpdir}/`basename ${bas}`_escaped
	sed  's/#/\\#/g'< ${bas} > ${bas_escaped}

	${perl} ${mbleu} ${ref_escaped} < ${bas_escaped} 2>&1 | grep -v "^BLEU" > ${tmpdir}/bleucounts_bas

	cat ${bas_escaped} | ${AWK} '{ print $0,"(TER-"NR")" }' > ${tmpdir}/ter_bas
	${java} -Xmx512m -jar ${tercom} -r ${tmpdir}/ter_ref -h ${tmpdir}/ter_bas > ${tmpdir}/ter_res_bas
	cat ${tmpdir}/ter_res_bas | grep "Sentence TER: "| cut -d ' ' -f 3,4 > ${tmpdir}/tercounts_bas

	${java} -Xmx512m -jar ${meteorcom} ${bas_escaped} ${ref_escaped} -l ${lan}  > ${tmpdir}/meteor_res_bas
	cat ${tmpdir}/meteor_res_bas | grep "Segment" |${AWK} 'BEGIN{FS="\t"}{print $2}' > ${tmpdir}/meteorcounts_bas

	basbleucnts=${tmpdir}/bleucounts_bas
	bastercnts=${tmpdir}/tercounts_bas
	basmeteorcnts=${tmpdir}/meteorcounts_bas
	
fi


${AWK} -v N=${nreps} -v interval=${interval} -v tmp=${tmpdir} -v size=${N} '
function precision (val) {
	pp=length(N)-3
	return int(val*(10**pp)+0.5)/(10**pp)
}{	if (ARGIND==1) bleucounts[FNR]=$0
	if (ARGIND==2) tercounts[FNR]=$0
        if (ARGIND==3) meteorcounts[FNR]=$0
        if (ARGIND==4) basbleucounts[FNR]=$0
	if (ARGIND==5) bastercounts[FNR]=$0
        if (ARGIND==6) basmeteorcounts[FNR]=$0                                                                                                                                                                     
} END {
	srand()
	printf "Computing confidence intervals with %d digits of precision...\n",length(N)-1
	for (n=1;n<=N;++n) {
		delete tercountacc; delete bleucountacc; delete meteorcountacc;
		if (ARGIND==6) { delete bastercountacc; delete basbleucountacc; delete basmeteorcountacc; }
		for (i=1;i<=FNR;++i) {
			id=int(rand()*size+1)
			split(tercounts[id], tp)
			tercountacc[1]+=tp[1]; tercountacc[2]+=tp[2]

			split(bleucounts[id], bp)
			for (j=1;j<=9;++j) bleucountacc[j]+=bp[j]

                        
                        meteorcountacc[1]+=meteorcounts[id];

			if (ARGIND==6) {
				split(bastercounts[id], tp)
				bastercountacc[1]+=tp[1]; bastercountacc[2]+=tp[2]
                                basmeteorcountacc[1]+=basmeteorcounts[id];      
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
                meteors[n]=meteorcountacc[1]/FNR
		if (ARGIND==6) { 
			baster[n]=bastercountacc[1]/bastercountacc[2]
                        basmeteor[n]=basmeteorcountacc[1]/FNR
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
                        meteordiffs[n]=meteors[n]-basmeteor[n]
			BPdiffs[n]=brevpenalties[n]-basbrevpenalties[n]
		}
	if (n%100==0) printf(".");
	}
	asort(bleus); asort(ters); asort(brevpenalties); asort(meteors)
	if (ARGIND==6) { asort(basbleu); asort(baster); asort(basbrevpenalties); asort(terdiffs); asort(bleudiffs); asort(BPdiffs); asort(basmeteor); asort(meteordiffs)}

	for (i=1;i<=N;++i) printf("%s ", ters[i]) > tmp"/ters"
	for (i=1;i<=N;++i) printf("%s ", bleus[i]) > tmp"/bleus"
        for (i=1;i<=N;++i) printf("%s ", meteors[i]) > tmp"/meteors"                                                                                                                                               
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
        lowermeteor=meteors[rest]*100;   uppermeteor=meteors[N-rest]*100                                                                                                                                           
        avgmeteor=(lowermeteor+uppermeteor)/2;  meteorint=uppermeteor-avgmeteor                                                                                                                                                     

    sumsq_bleu=0
    sumsq_ter=0
    sumsq_meteor=0
    for(i=1;i<=N;i++) {
          sumsq_bleu += (bleus[i]*100 - avgbleu)^2
          sumsq_ter += (ters[i]*100 - avgter)^2
          sumsq_meteor += (meteors[i]*100 - avgmeteor)^2
          }
          stdev_bleu=sqrt(sumsq_bleu/(N-1))
          stdev_ter=sqrt(sumsq_ter/(N-1))
          stdev_meteor=sqrt(sumsq_meteor/(N-1))

	printf "BLEU   %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %1.4f ) - BLEU stdev: %1.4f \n",interval,precision(lowerbleu),precision(upperbleu),avgbleu,bleuint,stdev_bleu
	printf "BP     %2.1f%% confidence interval:           %1.4f --  %1.4f ( %1.4f +- %1.4f ) \n",interval,precision(lowerBP*100)/100,precision(upperBP*100)/100,avgBP,BPint
	printf "TER    %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %1.4f ) - TER stdev: %1.4f \n",interval,precision(lowerter),precision(upperter),avgter,terint,stdev_ter
    printf "METEOR %2.1f%% confidence interval:           %2.4f -- %2.4f ( %2.4f +- %1.4f ) - METEOR stdev: %1.4f \n",interval,precision(lowermeteor),precision(uppermeteor),avgmeteor,meteorint,stdev_meteor

#	print "BLEU "interval"% confidence interval:            " lowerbleu " -- " upperbleu " ( " avgbleu " +- " bleuint " )"
#	print "BP   "interval"% confidence interval:            " lowerBP " -- " upperBP " ( " avgBP " +- " BPint " )"
#	print "TER  "interval"% confidence interval:            " lowerter " -- " upperter " ( " avgter " +- " terint " )"

	if (ARGIND==6) {
		print ""
		print "Confidence intervals for baseline:"
	        lowerbasbleu=basbleu[rest]*100;       upperbasbleu=basbleu[N-rest]*100
	        avgbasbleu=(lowerbasbleu+upperbasbleu)/2; basbleuint=upperbasbleu-avgbasbleu
					lowerbasBP=basbrevpenalties[rest];       upperbasBP=basbrevpenalties[N-rest]
					avgbasBP=(lowerbasBP+upperbasBP)/2; basBPint=upperbasBP-avgbasBP
	        lowerbaster=baster[rest]*100;         upperbaster=baster[N-rest]*100
	        avgbaster=(lowerbaster+upperbaster)/2;    basterint=upperbaster-avgbaster
                lowerbasmeteor=basmeteor[rest]*100;    upperbasmeteor=basmeteor[N-rest]*100                                                             
                avgbasmeteor=(lowerbasmeteor+upperbasmeteor)/2;    basmeteorint=upperbasmeteor-avgbasmeteor
		printf "BLEU    %2.1f%% confidence interval:       %2.4f -- %2.4f ( %2.4f +- %1.4f )\n",interval,precision(lowerbasbleu),precision(upperbasbleu),avgbasbleu,basbleuint
		printf "BP      %2.1f%% confidence interval:       %1.4f --  %1.4f (  %1.4f +- %1.4f )\n",interval,precision(lowerBP*100)/100,precision(upperBP*100)/100,avgbasBP,basBPint
		printf "TER     %2.1f%% confidence interval:       %2.4f -- %2.4f ( %2.4f +- %2.4f )\n",interval,precision(lowerbaster),precision(upperbaster),avgbaster,basterint
                printf "METEOR  %2.1f%% confidence interval:       %2.4f -- %2.4f ( %2.4f +- %2.4f )\n",interval,precision(lowerbasmeteor),precision(upperbasmeteor),avgbasmeteor,basmeteorint   
#	        print "BLEU "interval"% confidence interval:            " lowerbasbleu " -- " upperbasbleu " ( " avgbasbleu " +- " basbleuint " )"
#		print "BP   "interval"% confidence interval:            " lowerbasBP " -- " upperbasBP " ( " avgbasBP " +- " basBPint " )"
#	        print "TER  "interval"% confidence interval:            " lowerbaster " -- " upperbaster " ( " avgbaster " +- " basterint " )"
		
		print ""
		for (i=1;i<=N;++i) printf("%s ", terdiffs[i]) > tmp"/terdiffs"
                for (i=1;i<=N;++i) printf("%s ", meteordiffs[i]) > tmp"/meteordiffs"                                                           
		for (i=1;i<=N;++i) printf("%s ", bleudiffs[i]) > tmp"/bleudiffs"
		lowerbleudiff=bleudiffs[rest]*100;               upperbleudiff=bleudiffs[N-rest]*100
		avgbleudiff=(lowerbleudiff+upperbleudiff)/2;     bleuintdiff=upperbleudiff-avgbleudiff
		lowerBPdiff=BPdiffs[rest];               upperBPdiff=BPdiffs[N-rest]
		avgBPdiff=(lowerBPdiff+upperBPdiff)/2;     BPintdiff=upperBPdiff-avgBPdiff
		lowerterdiff=terdiffs[rest]*100;                 upperterdiff=terdiffs[N-rest]*100
		avgterdiff=(lowerterdiff+upperterdiff)/2;        terintdiff=upperterdiff-avgterdiff
                lowermeteordiff=meteordiffs[rest]*100;                 uppermeteordiff=meteordiffs[N-rest]*100                                                                    
                avgmeteordiff=(lowermeteordiff+uppermeteordiff)/2;        meteorintdiff=uppermeteordiff-avgmeteordiff     
		printf "BLEU    pairwise improvement %2.1f%% interval: % 2.4f -- % 2.4f ( % 2.4f +- % 1.4f )\n",interval,precision(lowerbleudiff),precision(upperbleudiff),avgbleudiff,bleuintdiff
		printf "BP      pairwise improvement %2.1f%% interval: % 2.4f -- % 2.4f ( % 2.4f +- % 1.4f )\n",interval,precision(lowerBPdiff*100)/100,precision(upperBPdiff*100)/100,avgBPdiff,BPintdiff
		printf "TER     pairwise improvement %2.1f%% interval: % 2.4f -- % 2.4f ( % 2.4f +- % 1.4f )\n",interval,precision(lowerterdiff),precision(upperterdiff),avgterdiff,terintdiff
                printf "METEOR  pairwise improvement %2.1f%% interval: % 2.4f -- % 2.4f ( % 2.4f +- % 1.4f )\n",interval,precision(lowermeteordiff),precision(uppermeteordiff),avgmeteordiff,meteorintdiff                         
#		print "BLEU pairwise improvement "interval"% interval: " lowerbleudiff " -- " upperbleudiff " ( " avgbleudiff " +- " bleuintdiff " )"
#		print "BP   pairwise improvement "interval"% interval: " lowerBPdiff " -- " upperBPdiff " ( " avgBPdiff " +- " BPintdiff " )"
#		print "TER pairwise improvement  "interval"% interval: " lowerterdiff " -- " upperterdiff " ( " avgterdiff " +- " terintdiff " )"
	}
}' ${tmpdir}/bleucounts ${tmpdir}/tercounts ${tmpdir}/meteorcounts ${basbleucnts} ${bastercnts} ${basmeteorcnts}




if [ "$bas" != "" ]; then  # computing pairwise improvement
    echo "Computing statistical significance with approximate_randomization..."
    cat ${tmpdir}/tercounts | ${AWK} '{print $1/$2}' >  ${tmpdir}/ters
    cat ${tmpdir}/tercounts_bas | ${AWK} '{print $1/$2}' >  ${tmpdir}/ters_bas

    cat ${tmpdir}/bleucounts | ${AWK} '{
             split($0, bp);
             for (j=1;j<=9;++j)
                bleucountacc[j]+=bp[j]
            if (bleucountacc[9] > bleucountacc[5])
                brevpen=exp(1-bleucountacc[9]/bleucountacc[5])
            else
                brevpen=1
            bleus=exp((log(bleucountacc[1]/bleucountacc[5]) + log(bleucountacc[2]/bleucountacc[6]) + log(bleucountacc[3]/bleucountacc[7]) + log(bleucountacc[4]/bleucountacc[8]))/4)*brevpen;
            print bleus }' > ${tmpdir}/bleus

    cat ${tmpdir}/bleucounts_bas | ${AWK} '{
             split($0, bp);
             for (j=1;j<=9;++j)
                bleucountacc[j]+=bp[j]
            if (bleucountacc[9] > bleucountacc[5])
                brevpen=exp(1-bleucountacc[9]/bleucountacc[5])
            else
                brevpen=1
            bleus=exp((log(bleucountacc[1]/bleucountacc[5]) + log(bleucountacc[2]/bleucountacc[6]) + log(bleucountacc[3]/bleucountacc[7]) + log(bleucountacc[4]/bleucountacc[8]))/4)*brevpen;
            print bleus }' > ${tmpdir}/bleus_bas


    echo "Computing significance level of BLEU"
    python ${DIR}/approximate_randomization_test.py ${tmpdir}/bleus_bas ${tmpdir}/bleus ${nreps}

    echo "Computing significance level of TER"
    python ${DIR}/approximate_randomization_test.py ${tmpdir}/ters_bas ${tmpdir}/ters ${nreps}

fi

exit
