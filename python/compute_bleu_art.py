# -*- coding: utf-8 -*-
from __future__ import print_function
from keras_wrapper.extra.read_write import file2list
from pycocoevalcap.sentence_bleu.sentence_bleu import SentenceBleuScorer
from builtins import zip
import argparse
from art import aggregators
from art.scores import Scores, Score
from art import significance_tests

parser = argparse.ArgumentParser(
    description="""Computes BLEU from a htypotheses file with respect to one or more reference files and compute significant differences using ART (approximate randomization tests).""",
    formatter_class=argparse.RawTextHelpFormatter)
parser.add_argument('-t', '--hypotheses', type=str, help='Hypotheses file')
parser.add_argument('-r', '--references', type=str, help='Path to all the reference files (single-reference files)')
parser.add_argument('-b', '--baseline', type=str, help='Baseline file')
parser.add_argument('-br', '--base-references', type=str, help='Baseline references file', required=False)
parser.add_argument('-n', '--n-reps', type=int, default=10000,
                    help='Number of ART iterations')


def evaluate_from_file(args):
    """
    Evaluate translation hypotheses from a file or a list of files of references.
    :param args: Evaluation parameters
    :return: None
    """
    hypotheses = file2list(args.hypotheses)
    references = file2list(args.references)
    baseline = file2list(args.baseline)

    base_refs = args.references if args.base_references is None else args.base_references
    baseline_refs = file2list(base_refs)
    sentence_bleu_scorer = SentenceBleuScorer('')
    bleus = []
    for hyp_line, ref_line in zip(hypotheses, references):
        sentence_bleu_scorer.set_reference(ref_line.split())
        bleu = sentence_bleu_scorer.score(hyp_line.split())
        bleus.append(bleu)
    bleus_baseline = []
    for hyp_line, ref_line in zip(baseline, baseline_refs):
        sentence_bleu_scorer.set_reference(ref_line.split())
        bleu = sentence_bleu_scorer.score(hyp_line.split())
        bleus_baseline.append(bleu)

    print("Average BLEU hypotheses: " + str(float(sum(bleus)) / len(bleus)))
    print("Average BLEU baseline:   " + str(float(sum(bleus_baseline)) / len(bleus_baseline)))

    scores_system = []
    scores_baseline = []
    for bleu in bleus:
        scores_system.append(Score([bleu]))

    for bleu in bleus_baseline:
        scores_baseline.append(Score([bleu]))

    scores_system = Scores(scores_system)
    scores_baseline = Scores(scores_baseline)

    test = significance_tests.ApproximateRandomizationTest(
        scores_system,
        scores_baseline,
        aggregators.average,
        trials=int(args.n_reps))

    print("\t Significance level:", test.run())


if __name__ == "__main__":
    evaluate_from_file(parser.parse_args())
