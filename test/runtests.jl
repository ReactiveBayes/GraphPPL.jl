using ReTestItems, GraphPPL, Aqua

Aqua.test_all(GraphPPL; ambiguities = (broken = true,))

runtests(GraphPPL)
