import matplotlib.pyplot as plt
import numpy as np
import os
import csv

# Clean plot
plt.close()
plt.figure(figsize=(15, 10), dpi=100)
x_plots = 1
y_plots = 1

# load curves
be2013 = np.genfromtxt("/Users/kruip/Projects/merit-convergence/data/nl/interconnector_load_curves/BE_NL_2013.csv", delimiter = ',')
be2023 = np.genfromtxt("/Users/kruip/Projects/merit-convergence/data/nl/interconnector_load_curves/BE_NL_2023.csv", delimiter = ',')
gbr = np.genfromtxt("/Users/kruip/Projects/merit-convergence/data/nl/interconnector_load_curves/GBR_NL.csv", delimiter = ',')
nor2013 = np.genfromtxt("/Users/kruip/Projects/merit-convergence/data/nl/interconnector_load_curves/NOR_NL_2013.csv", delimiter = ',')
nor2023 = np.genfromtxt("/Users/kruip/Projects/merit-convergence/data/nl/interconnector_load_curves/NOR_NL_2023.csv", delimiter = ',')

#ofile = open("/Users/kruip/Projects/merit-convergence/data/nl/interconnector_load_curves/NOR_NL_2023.csv","w")
#for i in range(0,len(nor2013)):
#    if i > 7234 and i < 8481:
#        ofile.write("700\n")
#    else:
#        ofile.write(""+str(nor2013[i])+"\n")
#
#ofile.close()

year = 8760

plt.title("Import of electricity")
plt.subplot(y_plots, x_plots, 1)
plt.plot(be2013, label="BE_NL 2013")
plt.plot([1501]*year, 'b--', label ="BE->NL capacity 2013")
plt.plot(be2023, label="BE_NL 2023")
plt.plot([2001]*year, 'g--', label ="BE->NL capacity 2023")
plt.plot(gbr, label="GBR_NL")
plt.plot([1000]*year, 'r--', label ="GBR->NL capacity 2013")
plt.plot(nor2013, label="NOR_NL 2013")
plt.plot([700]*year, 'k--', label ="NOR->NL capacity 2013")
#plt.plot(nor2023, label="NOR_NL 2023")

plt.legend(bbox_to_anchor=[0.99, 0.99])
plt.ylabel('MW')
plt.xlabel('hours')
plt.show()
