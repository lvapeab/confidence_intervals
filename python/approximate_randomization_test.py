import sys
from art import aggregators
from art import scores
from art import significance_tests

test = significance_tests.ApproximateRandomizationTest(
    scores.Scores.from_file(open(sys.argv[1])),
    scores.Scores.from_file(open(sys.argv[2])),
    aggregators.average,
    trials=int(sys.argv[3]))

print ("\t Significance level:",  test.run())

