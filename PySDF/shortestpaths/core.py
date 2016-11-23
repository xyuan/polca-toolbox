
class NegativeCycleException( BaseException ):
    def __init__(self, info = None):
        super().__init__()
        self.info = info
        self.cycle = info

def testcases(prefix = 'RAND5', cases = 10, nodes = 1000, edges = 5000, cycles = 0, length = 3):
    for case in range(cases):
        fname = '{}_{:02}.dimacs'.format(prefix, case + 1)
        g = sprand( nodes, edges )
        negcycle(g, cycles, length )
        dimacs(g, 0, fname)

def dimacs(g, root, fname):
    f = open(fname, 'w')
    f.write('c\trandom graph generated by python implementation of SPRAND\n')
    f.write('c\n')
    f.write('p\tsp\t{}\t{}\n'.format(g.number_of_nodes(), g.number_of_edges()))
    f.write('c\n')
    f.write('t\trd_{}_{}\n'.format(g.number_of_nodes(), g.number_of_edges()))
    f.write('c\n')
    f.write('n\t{}\n'.format(root))
    for v, w, data in g.edges( data = True ):
        f.write('a\t{}\t{}\t{}\n'.format(v, w, data['weight']))
    print('Written {} arcs'.format(g.number_of_edges()))

