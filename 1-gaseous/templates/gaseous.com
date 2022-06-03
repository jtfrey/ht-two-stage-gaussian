%chk=[{% print(CHEMICAL) %}].chk
%nproc=[{% print(str(NPROC)) %}]
%mem=[{% print('{:.0f}'.format(0.95*NPROC*MEM_PER_PROC)) %}]MB
#p nosymm M062x/aug-cc-pVDZ opt(maxcyc=800) Volume iop(6/45=1000) freq

[{% print(CHEMICAL) %}] - gas phase optimization

[{%
with open('{:s}/{:s}.xyz'.format(CHEMICALS_DIR, CHEMICAL)) as f:
    print(f.read())
%}]
