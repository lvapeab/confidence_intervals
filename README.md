# confidence_intervals
Bootstrap resampling for some tasks

## MT quality: Bleu - TER

```
Usage:	 confindence intervals.sh <-r reference> <-t hypothesis> <-n nreps> 
 	                          [-b baseline] [-i interval] [-y] [-v] [-h] 
 	 This script will take up a reference file and a hypothesis file and compute TER and BLEU confidence 
 	 intervals by means of bootstrapping. Note: This script needs a *modified* version of TERCOM and 
 	 multi-bleu.perl. These two modified versions are included into this script for simplicity purposes and 
 	 unpacked on the fly. If [-b baseline] is specified, pairwise improvement intervals will also be computed. 
 Input:	 -r reference: file containing the reference translations. 
 	 -b baseline: file containing the baseline translations. If specified, pair 
 	 -t hypothesis: file containing the (machine) translations to be evaluated. 
 	 -n nreps: number of repetitions to do via bootstrapping. 
 	 -i interval: confidence interval to compute (default 95) 
 	 -y: do not delete temporary files. 
 	 -v: activate verbose mode (set -x). 
 	 -h: show this help and exit. 
 Output: - confidence interval
```

## IMT effort estimation: WSR - MAR (or other metrics)
```
Usage:	 imt_confindence intervals.sh <-t scores> <-n nreps> 
 	                          [-b baseline] [-i interval] [-y] [-v] [-h] 
 	 This script will take up a WSR and MAR scores file and compute MAR and WSR confidence 
 	 intervals by means of bootstrapping. If [-b baseline] is specified, pairwise improvement 
 	 intervals will also be computed. 
 Input:	 -b baseline: file containing the baseline scores. If specified, pair 
 	 -t scores: file containing the scores to be evaluated. 
 	 -n nreps: number of repetitions to do via bootstrapping. 
 	 -i interval: confidence interval to compute (default 95) 
 	 -y: do not delete temporary files. 
 	 -v: activate verbose mode
 	 -h: show this help and exit. 
 Output: - confidence interval
```
