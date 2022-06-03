%chk=[{% print('{:s}_{:s}.chk'.format(CHEMICAL,SOLVENT.replace(',','_').replace('-','_').replace(' ',''))) %}]
%nproc=[{% print(str(NPROC)) %}]
%mem=[{% print('{:.0f}'.format(0.95*NPROC*MEM_PER_PROC)) %}]MB
#p nosymm M062x/aug-cc-pVDZ opt(maxcyc=200) Volume iop(6/45=1000) Geom=AllCheck Guess=Read SCRF=(SMD,Solvent=[{% print(SOLVENT) %}]) freq

[{% print(CHEMICAL) %}] - [{% print(SOLVENT) %}]-solvated optimization


