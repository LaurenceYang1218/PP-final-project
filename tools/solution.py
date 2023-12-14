import sys
import random
import networkx as nx
import pickle
from argparse import ArgumentParser

def loadGraph(file : str):
    with open(file, 'rb') as f:
        graph = pickle.load(f)

    return graph

if __name__ == "__main__":

    parser = ArgumentParser()
    parser.add_argument('-s', type=int, help='src node')
    parser.add_argument('-d', type=int, help='dst node')
    parser.add_argument('-f', default="general_graph.pkl", type=str, help='pickle file for graph')
    args = parser.parse_args()


    G = loadGraph(args.f)
    
    srcNode = args.s
    dstNode = args.d

    print("Groud Truth:", nx.shortest_path_length(G, srcNode, dstNode, weight='weight', method='dijkstra'), file=sys.stderr)