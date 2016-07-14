import argparse
import logging
import sys
from collections import OrderedDict
from my_pycocoevalcap.bleu.bleu import Bleu
from my_pycocoevalcap.rouge.rouge import Rouge
from my_pycocoevalcap.cider.cider import Cider
from my_pycocoevalcap.meteor.meteor import Meteor
from my_pycocoevalcap.tokenizer.ptbtokenizer import PTBTokenizer
import os, cPickle

logging.basicConfig(level=logging.DEBUG, format='%(asctime)s %(message)s', datefmt='%d/%m/%Y %I:%M:%S %p')
logger = logging.getLogger(__name__)


class COCOScorer(object):

    def score(self, GT, RES, IDs):
        self.eval = {}
        self.imgToEval = {}
        gts = {}
        res = {}
        for ID in IDs:
            gts[ID] = GT[ID]
            res[ID] = RES[ID]
        tokenizer = PTBTokenizer()
        gts  = tokenizer.tokenize(gts)
        res = tokenizer.tokenize(res)

        # =================================================
        # Set up scorers
        # =================================================
        scorers = [
            (Bleu(4), ["Bleu_1", "Bleu_2", "Bleu_3", "Bleu_4"]),
            (Meteor(),"METEOR"),
            (Rouge(), "ROUGE_L"),
            (Cider(), "CIDEr")
        ]
        eval = {}
        # =================================================
        # Compute scores
        # =================================================
        for scorer, method in scorers:
            sys.stderr.write('Computing %s metric...\n'%str(method))
            score, scores = scorer.compute_score(gts, res, verbose=0)
            if type(method) == list:
                for j in range(len(scores)): # j : 1 .. 4
                    eval[method[j]] = []
                    for i in range(len(scores[0])): # i: 1 .. 670
                        eval[method[j]].append(scores[j][i])
            else:
                eval[method] = scores
        scores_list = ''
        for i in range(len(eval[scorers[0][1][0]])):
            for _, method in scorers:
                if type(method) == list:
                    for m in method:
                        scores_list += '%0.4f'%float(eval[m][i]) + " "
                else:
                    scores_list += '%0.4f'%float(eval[method][i]) + " "
            scores_list += '\n'

        print scores_list
        return self.eval

    def setEval(self, score, method):
        self.eval[method] = score

    def setImgToEvalImgs(self, scores, imgIds, method):
        for imgId, score in zip(imgIds, scores):
            if not imgId in self.imgToEval:
                self.imgToEval[imgId] = {}
                self.imgToEval[imgId]["image_id"] = imgId
            self.imgToEval[imgId][method] = score

def load_pkl(path):
    f = open(path, 'rb')
    try:
        rval = cPickle.load(f)
    finally:
        f.close()
    return rval

def score(ref, sample):
    # ref and sample are both dict
    scorers = [
        (Bleu(4), ["Bleu_1", "Bleu_2", "Bleu_3", "Bleu_4"]),
        (Meteor(),"METEOR"),
        (Rouge(), "ROUGE_L"),
        (Cider(), "CIDEr")
    ]
    final_scores = {}
    for scorer, method in scorers:
        print 'computing %s score with COCO-EVAL...'%(scorer.method())
        score, scores = scorer.compute_score(ref, sample)
        if type(score) == list:
            for m, s in zip(method, score):
                final_scores[m] = s
        else:
            final_scores[method] = score
    print final_scores
    return final_scores

def test_cocoscorer():
    '''gts = {
        184321:[
        {u'image_id': 184321, u'id': 352188, u'caption': u'A train traveling down-tracks next to lights.'},
        {u'image_id': 184321, u'id': 356043, u'caption': u"A blue and silver train next to train's station and trees."},
        {u'image_id': 184321, u'id': 356382, u'caption': u'A blue train is next to a sidewalk on the rails.'},
        {u'image_id': 184321, u'id': 361110, u'caption': u'A passenger train pulls into a train station.'},
        {u'image_id': 184321, u'id': 362544, u'caption': u'A train coming down the tracks arriving at a station.'}],
        81922: [
        {u'image_id': 81922, u'id': 86779, u'caption': u'A large jetliner flying over a traffic filled street.'},
        {u'image_id': 81922, u'id': 90172, u'caption': u'An airplane flies low in the sky over a city street. '},
        {u'image_id': 81922, u'id': 91615, u'caption': u'An airplane flies over a street with many cars.'},
        {u'image_id': 81922, u'id': 92689, u'caption': u'An airplane comes in to land over a road full of cars'},
        {u'image_id': 81922, u'id': 823814, u'caption': u'The plane is flying over top of the cars'}]
        }

    samples = {
        184321: [{u'image_id': 184321, 'id': 111, u'caption': u'train traveling down a track in front of a road'}],
        81922: [{u'image_id': 81922, 'id': 219, u'caption': u'plane is flying through the sky'}],
        }
    '''
    gts = {
        '184321':[
        {u'image_id': '184321', u'cap_id': 0, u'caption': u'A train traveling down tracks next to lights.',
         'tokenized': 'a train traveling down tracks next to lights'},
        {u'image_id': '184321', u'cap_id': 1, u'caption': u'A train coming down the tracks arriving at a station.',
         'tokenized': 'a train coming down the tracks arriving at a station'}],
        '81922': [
        {u'image_id': '81922', u'cap_id': 0, u'caption': u'A large jetliner flying over a traffic filled street.',
         'tokenized': 'a large jetliner flying over a traffic filled street'},
        {u'image_id': '81922', u'cap_id': 1, u'caption': u'The plane is flying over top of the cars',
         'tokenized': 'the plan is flying over top of the cars'},]
        }

    samples = {
        '184321': [{u'image_id': '184321', u'caption': u'train traveling down a track in front of a road'}],
        '81922': [{u'image_id': '81922', u'caption': u'plane is flying through the sky'}],
        }
    IDs = ['184321', '81922']
    scorer = COCOScorer()
    scorer.score(gts, samples, IDs)

def build_sample_pairs(samples, vid_ids):
    d = OrderedDict()
    for sample, vid_id in zip(samples, vid_ids):
        d[vid_id] = [{'image_id': vid_id, 'caption': sample}]
    return d

def load_txt_file(path):
    f = open(path,'r')
    lines = f.readlines()
    f.close()
    return lines


def main(text, task='youtube', dataset='test', pkl_name='./youtube.CAP.pkl', verbose=False):

    if verbose:
        logger.debug("Configuration:")
        logger.debug("\t text: %s" % text)
        logger.debug("\t task: %s" % task)
        logger.debug("\t dataset: %s" % dataset)
        logger.debug("\t pkl_name: %s" % pkl_name)

    with open(pkl_name, 'r') as f:
        caps = cPickle.load(f)
    samples = load_txt_file(text)
    samples = [sample.strip() for sample in samples]

    if task == 'youtube':
        if dataset == 'valid':
            ids = ['vid%s' % i for i in range(1201, 1301)]
        else:
            ids = ['vid%s' % i for i in range(1301, 1971)]

    samples = build_sample_pairs(samples, ids)

    scorer = COCOScorer()
    gts = OrderedDict()
    for vidID in ids:
        gts[vidID] = caps[vidID]
    score = scorer.score(gts, samples, ids)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('-t', '--task', type=str, default='youtube', help="Task we are computing the metrics (youtube, "
                                                                          "flickr30k, flickr8k)")
    parser.add_argument('-d', '--dataset', type=str, default='test', help="which dataset to use (dev or test)")
    parser.add_argument('-c', '--caps', type=str, default='./youtube.CAP.pkl',
                        help=".pkl file containing the captions info")
    parser.add_argument('-v', '--verbose', type=str, help="Be verbose")
    parser.add_argument('text', type=str, help="Hypotheses file")
    args = parser.parse_args()

    main(args.text, task=args.task, dataset=args.dataset, pkl_name=args.caps, verbose=args.verbose)