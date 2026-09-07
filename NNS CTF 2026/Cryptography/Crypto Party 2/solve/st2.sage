load("attack2.sage")
g,t=selftest(5)
open("st2_out.txt","w").write("selftest %d/%d\n"%(g,t))
