      Subroutine  GetIntegratedNCXsection(IDataSet)
C----------------------------------------------------------------
C
C  NC Double differential integrated cross section calculation
C  Fills global array THEO.
C  
C  Created by Krzysztof Nowak, 20/01/2012
C---------------------------------------------------------------

      implicit none
      include 'ntot.inc'
      include 'couplings.inc'
      include 'datasets.inc'
      include 'indata.inc'
      include 'theo.inc'

      integer IDataSet
      integer idxQ2min, idxQ2max, idxYmin, idxYmax, idxXmin, idxXmax
      integer i,  idx, iq2, ix, j, kkk
      
      integer NPmax
      parameter(NPmax=1000)

      integer nq2split
      parameter(nq2split=25)
      integer nxsplit
      parameter(nxsplit=25)

      double precision X(NPmax),Y(NPmax),Q2(NPmax),XSecP(NPmax),XSecN(NPmax), S
      double precision q2_1, q2_2, alphaem_run, factorNC, XSec, YPlus
      double precision dq2(NPmax), dx(NPmax)
      double precision Charge, polarity
      double precision q2min,q2max,xmin,xmax
      double precision EmToEtotRatio
      logical LoopOverYBins
      integer NSubBins

C Functions:
      integer GetBinIndex
      integer GetInfoIndex
      double precision AEMRUN

C---------------------------------------------------------

      if ((nq2split+1)*(nxsplit+1).gt.NPmax) then
         print *,'ERROR IN GetIntegratedNCXsection'
         print *,'INCREASE NPMax to ',(nq2split+1)*(nxsplit+1)
         stop
      endif

C
C Get indexes for Q2, x and y bins:
C
      idxQ2min = GetBinIndex(IDataSet,'q2min')
      idxXmin  = GetBinIndex(IDataSet,'xmin')
      idxYmin = GetBinIndex(IDataSet,'ymin')
      idxQ2max = GetBinIndex(IDataSet,'q2max')
      idxXmax  = GetBinIndex(IDataSet,'xmax')
      idxYmax = GetBinIndex(IDataSet,'ymax')
      LoopOverYBins = .false.
      S = (DATASETInfo( GetInfoIndex(IDataSet,'sqrt(S)'), IDataSet))**2
      EmToEtotRatio=(DATASETInfo(GetInfoIndex(IDataSet,'lumi(e-)/lumi(tot)'),IDataSet))

      if (idxQ2min.eq.0 .or. idxQ2max.eq.0) then
         print *, 'Q2 bins not well defined in a data file'
         Return
      endif
      if (idxXmin.eq.0 .or. idxXmax.eq.0) then
         if (idxYmin.eq.0 .or. idxYmax.eq.0) then
            print *, 'X or Y bins need to be defined in a data file            '
            Return
         endif
         LoopOverYBins = .true.
      endif

      do i=1,NDATAPOINTS(IDataSet)
         idx =  DATASETIDX(IDataSet,i)

         if(idx.gt.1) then      ! maybe I can just copy previous entry
            if((AbstractBins(idxQ2min,idx).eq.AbstractBins(idxQ2min,idx-1)).and.
     +       (AbstractBins(idxQ2max,idx).eq.AbstractBins(idxQ2max,idx-1)).and.
     +       (AbstractBins(idxXmin,idx).eq.AbstractBins(idxXmin,idx-1)).and.
     +       (AbstractBins(idxXmax,idx).eq.AbstractBins(idxXmax,idx-1)).and.
     +       (AbstractBins(idxYmin,idx).eq.AbstractBins(idxYmin,idx-1)).and.
     +       (AbstractBins(idxYmax,idx).eq.AbstractBins(idxYmax,idx-1))) then
               THEO(idx) = THEO(idx-1)
               cycle
            endif
         endif

         q2min = AbstractBins(idxQ2min,idx)
         q2max = AbstractBins(idxQ2max,idx)

         j=0
         do iq2=0,nq2split
            q2_1 = q2_2
            q2_2 = exp( log(q2min) + (log(q2max) - log(q2min)) / nq2split*dble(iq2))            
            if(iq2.gt.0) then
               do ix=0, nxsplit-1
                  j=j+1
                  dq2(j) = q2_2 - q2_1
                  q2(j) = exp( log(q2_1) + 0.5*(log(q2_2) - log(q2_1)) ) 

                  
                  if(LoopOverYBins) then
                     xmax = q2(j) / (S * AbstractBins(idxYmin,idx))
                     xmin = q2(j) / (S * AbstractBins(idxYmax,idx))
                  else
                     xmax = AbstractBins(idxXmax,idx)
                     xmin = AbstractBins(idxXmin,idx)
                  endif
                  
c                  S = 4.*27.5*920.
cc now I do transformation dx <-> dy to compare with the old code            
c                  xmin = AbstractBins(idxYmin,idx)
c                  xmax = AbstractBins(idxYmax,idx)
c                  y(j) = xmin + (xmax-xmin)/dble(nxsplit)*(dble(ix)+0.5)
c                  dx(j) = (xmax-xmin) / dble(nxsplit)
c                  x(j) = q2(j) / (S * y(j))
                  x(j) = xmin + (xmax-xmin)/dble(nxsplit)*(dble(ix)+0.5)
                  dx(j) = (xmax-xmin) / dble(nxsplit)
                  y(j) = q2(j) / (S * x(j))
               enddo
            endif
         enddo                  ! loop over q2 subgrid
         NSubBins = j

         polarity = 0.D0
         call CalcReducedXsectionForXYQ2(X,Y,Q2,NSubBins, 1.D0,polarity,IDataSet,XSecP)
         call CalcReducedXsectionForXYQ2(X,Y,Q2,NSubBins,-1.D0,polarity,IDataSet,XSecN)

         XSec = 0.D0
         do j=1, NSubBins
            XSecP(j) = EmToEtotRatio*XSecN(j) + (1.D0-EmToEtotRatio)*XSecP(j)

            Yplus  = 1. + (1.-y(j))**2
            XSecP(j) = XSecP(j) * YPlus

            alphaem_run = aemrun(q2(j))
            factorNC=2*pi*alphaem_run**2/(x(j)*q2(j)**2)*convfac

            XSecP(j) = XSecP(j) * factorNC
            XSecP(j) = XSecP(j) * dq2(j)
            XSecP(j) = XSecP(j) * dx(j)

            XSec = XSec+XSecP(j)
         enddo
         
         THEO(idx) =  XSec
c temporary divide over dq2
c         THEO(idx) =  XSec / (q2max - q2min)
c         print *, idx, ':', THEO(idx)
c         stop
      enddo   ! loop over data points

      end



      Subroutine GetReducedNCXsection(IDataSet)
C----------------------------------------------------------------
C
C  NC Double differential reduced cross section calculation for dataset IDataSet
C  Fills global array THEO.
C
C  Created by SG, 25/05/2011
C  Start with zero mass implementation
C                 14/06/2011 : re-introduce RT code
C---------------------------------------------------------------
      implicit none
      include 'ntot.inc'
      include 'steering.inc'
      include 'datasets.inc'
      include 'indata.inc'
      include 'theo.inc'
      include 'fcn.inc'

      integer IDataSet
      integer idxQ2, idxX, idxY, i,  idx
      
      integer NPmax
      parameter(NPmax=1000)

      double precision X(NPmax),Y(NPmax),Q2(NPmax),XSec(NPmax)
      double precision Charge, polarity

C Functions:
      integer GetBinIndex

c H1qcdfunc
      integer ifirst
      data ifirst /1/
C---------------------------------------------------------


      if (NDATAPOINTS(IDataSet).gt.NPmax) then
         print *,'ERROR IN GetReducedNCXsection'
         print *,'INCREASE NPMax to ',NDATAPOINTS(IDataSet)
         stop
      endif

C
C Get indexes for Q2, x and y bins:
C
      idxQ2 = GetBinIndex(IDataSet,'Q2')
      idxX  = GetBinIndex(IDataSet,'x')
      idxY = GetBinIndex(IDataSet,'y')

      if (idxQ2.eq.0 .or. idxX.eq.0 .or. idxY.eq.0) then
         Return
      endif

C prepare bins:
      do i=1,NDATAPOINTS(IDataSet)
C
C Reference from the dataset to a global data index:
C
         idx =  DATASETIDX(IDataSet,i)
C
C Local X,Y,Q2 arrays, used for QCDNUM SF caclulations:
C
         X(i)   = AbstractBins(idxX,idx)
         Y(i)   = AbstractBins(idxY,idx)
         Q2(i)  = AbstractBins(idxQ2,idx)
      enddo

      call ReadPolarityAndCharge(idataset,charge,polarity)

      call CalcReducedXsectionForXYQ2(X,Y,Q2,NDATAPOINTS(IDataSet),charge,polarity,IDataSet,XSec)

      do i=1,NDATAPOINTS(IDataSet)
         idx =  DATASETIDX(IDataSet,i)
         THEO(idx) =  XSec(i)
      enddo

      if ((iflagFCN.eq.3).and.(h1QCDFUNC)) then
         if (ifirst.eq.1) then
            print*,'getting output for the H1QCDFUNC'
        
            call GetH1qcdfuncOutput(charge, polarity)
            ifirst=0
            
         endif
      endif
      end


      Subroutine ReadPolarityAndCharge(idataset,charge,polarity)
C----------------------------------------------------------------
C
C  Get polarity and charge from the data file
C
C  Created by Krzysztof Nowak, 18/01/2012
C---------------------------------------------------------------

      implicit none
      include 'ntot.inc'
      include 'datasets.inc'
      include 'polarity.inc'

C Input:
      integer IDataSet

C Output:
      double precision charge, polarity

      double precision err_pol_unc, shift_pol
      double precision err_pol_corL
      double precision err_pol_corT

C Functions:
      integer GetInfoIndex

      polarity=0.d0
      err_pol_unc=0.d0
      err_pol_corL=0.d0
      err_pol_corT=0.d0
      polarity = DATASETInfo( GetInfoIndex(IDataSet,'e polarity'),
     $     IDataSet)
      if (polarity.ne.0) then
         err_pol_unc = 
     $        DATASETInfo( GetInfoIndex(IDataSet,'pol err unc'), IDataSet)
         err_pol_corL = 
     $        DATASETInfo( GetInfoIndex(IDataSet,'pol err corLpol'), IDataSet)
         err_pol_corT = 
     $        DATASETInfo( GetInfoIndex(IDataSet,'pol err corTpol'), IDataSet)
      endif
      charge = DATASETInfo( GetInfoIndex(IDataSet,'e charge'), IDataSet)

      if (charge.lt.0.) then
         if (polarity.gt.0) then
            shift_pol=shift_polRHm
         else
            shift_pol=shift_polLHm
         endif
      else
         if (polarity.gt.0) then
            shift_pol=shift_polRHp
         else
            shift_pol=shift_polLHp
         endif
      endif

      polarity=polarity*(1+err_pol_unc/100*shift_pol+
     $     err_pol_corL/100*shift_polL+
     $     err_pol_corT/100*shift_polT)

c
c      if(polarity.ne.0.d0) then
c         print '( ''charge:  '', F8.4, 
c     $        '' pol: '', F16.4, 
c     $        ''shift pol: '', F16.4 , 
c     $        ''shift Lpol: '', F16.4 , 
c     $        ''shift Tpol: '', F16.4 )', 
c     $        charge, polarity,shift_pol,shift_polL,shift_polT
c      endif
c
      end


      Subroutine CalcReducedXsectionForXYQ2(X,Y,Q2,npts,charge,polarity,idataset,XSec)
C----------------------------------------------------------------
C
C  NC Double differential reduced cross section calculation for a table given by X, Y, Q2
C  Fills array XSec
C
C  Created by Krzysztof Nowak, 18/01/2012
C---------------------------------------------------------------
      implicit none
      include 'ntot.inc'
      include 'steering.inc'
      include 'datasets.inc'
      include 'couplings.inc'
      include 'qcdnumhelper.inc'
      include 'fcn.inc'

      double precision ve,ae,au,ad,vu,vd,A_u,A_d,B_u,B_d,pz

      integer i, idx
      

      integer NPmax
      parameter(NPmax=1000)

C Input:
      integer npts,IDataSet
      double precision X(NPmax),Y(NPmax),Q2(NPmax)
      double precision Charge, polarity
C Output: 
      double precision XSec(NPmax)
      double precision yplus, yminus
c
      double precision F2p(NPmax),xF3p(NPmax),FLp(NPmax)
      double precision F2m(NPmax),xF3m(NPmax),FLm(NPmax)
      
      double precision F2,xF3,FL

      double precision FLGamma, F2Gamma
      logical UseKFactors

C RT:
      Double precision f2pRT,flpRT,f1pRT,rpRT,f2nRT,flnRT,f1nRT,rnRT,
     $     f2cRT,flcRT,f1cRT,f2bRT,flbRT,f1bRT, F2rt, FLrt

C HF:
      double precision NC2FHF(-6:6)
      double precision FLc, F2c, FLb, F2b
      dimension FLc(NPmax),F2c(NPmax),FLb(NPmax),F2b(NPmax)

c EW param

      double precision sin2th_eff, xkappa, epsilon
      double precision deltar,sweff, sin2thw2
      double precision cau, cad, cvu, cvd


c ACOT 
      double precision f123l(4),f123lc(4),f123lb(4),f2nc

C---------------------------------------------------------



      if (IFlagFCN.eq.1) then
C
C Execute for the first iteration only.
C
         if (HFSCHEME.eq.22.or.HFSCHEME.eq.11.or.HFSCHEME.eq.1) then
            UseKFactors = .true.
         else
            UseKFactors = .false.
         endif
      endif


C Protect against overflow of internal arrays:
C
      if (npts.gt.NPmax) then
         print *,'ERROR IN CalculateReducedXsection'
         print *,'INCREASE NPMax to ',npts
         stop
      endif


      if(EWFIT.eq.0) then
C
C EW couplings of the electron
C
         ve = -0.5d0 + 2.*sin2thw
         ae = -0.5d0         

C
C and quarks
C         
         
         au = 0.5d0
         ad = -0.5d0
                  
         vu = au - (4.d0/3.d0)*sin2thw
         vd = ad + (2.d0/3.d0)*sin2thw
      else

         call wrap_ew(q2,sweff,deltar,cau,cad,cvu,cvd,polarity,charge)

         sin2thw2 = 1.d0 - MW**2/MZ**2
         sin2th_eff = 0.23134d0
         xkappa = sin2th_eff/sin2thw
         epsilon = xkappa -1.0
         ve = -0.5d0 + 2.*sin2th_eff
         ae = -0.5d0

         vu = cvu - (4.d0/3.d0)*epsilon*sin2thw2
         vd = cvd + (2.d0/3.d0)*epsilon*sin2thw2
         au = cau
         ad = cad

      endif



C QCDNUM ZMVFNS, caclulate FL, F2 and xF3 for d- and u- type quarks all bins:

C u-type ( u+c ) contributions 
      CALL ZMSTFUN(1,CNEP2F,X,Q2,FLp,npts,0)
      CALL ZMSTFUN(2,CNEP2F,X,Q2,F2p,npts,0)
      CALL ZMSTFUN(3,CNEP3F,X,Q2,XF3p,npts,0)    

C d-type (d + s + b) contributions
      CALL ZMSTFUN(1,CNEM2F,X,Q2,FLm,npts,0)
      CALL ZMSTFUN(2,CNEM2F,X,Q2,F2m,npts,0)
      CALL ZMSTFUN(3,CNEM3F,X,Q2,XF3m,npts,0) 

C heavy quark contribution (c and b)      
      if (mod(HFSCHEME,10).eq.3) then 

         NC2FHF = 4.D0/9.D0 * CNEP2F  + 1.D0/9.D0 * CNEM2F
c        write(6,*) 'NC2FHF:', NC2FHF

         CALL HQSTFUN(2,1,NC2FHF,X,Q2,F2c,npts,0)
         CALL HQSTFUN(1,1,NC2FHF,X,Q2,FLc,npts,0)
         CALL HQSTFUN(2,-2,NC2FHF,X,Q2,F2b,npts,0)
         CALL HQSTFUN(1,-2,NC2FHF,X,Q2,FLb,npts,0)
c         write(6,*) 'HQSTFUN: X,Q2,F2c,FLc', X(1),Q2(1),F2c(1),FLc(1)
c         write(6,*) 'HQSTFUN: X,Q2,F2b,FLb', X(1),Q2(1),F2b(1),FLb(1)

      endif

      do i=1,npts

C Get the index of the point in the global data table:
         idx =  DATASETIDX(IDataSet,i)

C Propagator factor PZ
         PZ = 4.d0 * sin2thw * cos2thw * (1.+Mz**2/Q2(i))

C modify propagator for EW corrections -- only for EW fit
         if (EWfit.ne.0) PZ = PZ * (1.d0 - Deltar)

         PZ = 1./Pz
C EW couplings of u-type and d-type quarks at the scale Q2

         if (charge.gt.0) then
            A_u = e2u           ! gamma
     $           + (-ve-polarity*ae)*PZ*2.*euq*vu !gamma-Z
     $           + (ve**2 + ae**2+2*polarity*ve*ae)*PZ**2*(vu**2+au**2) !Z
            
            A_d = e2d 
     $           + (-ve-polarity*ae)*PZ*2.*edq*vd 
     $           + (ve**2 + ae**2+2*polarity*ve*ae)*PZ**2*(vd**2+ad**2)
            
            B_u = (ae+polarity*ve)*PZ*2.*euq*au !gamma-Z
     $           + (-2.*ve*ae-polarity*(ve**2+ae**2))*(PZ**2)*2.*vu*au !Z
            B_d = (ae+polarity*ve)*PZ*2.*edq*ad 
     $           + (-2.*ve*ae-polarity*(ve**2+ae**2))*(PZ**2)*2.*vd*ad
         else
            A_u = e2u           ! gamma
     $           + (-ve+polarity*ae)*PZ*2.*euq*vu !gamma-Z
     $           + (ve**2 + ae**2-2*polarity*ve*ae)*PZ**2*(vu**2+au**2) !Z
            
            A_d = e2d 
     $           + (-ve+polarity*ae)*PZ*2.*edq*vd 
     $           + (ve**2 + ae**2-2*polarity*ve*ae)*PZ**2*(vd**2+ad**2)
            
            B_u = (-ae+polarity*ve)*PZ*2.*euq*au !gamma-Z
     $           + (2.*ve*ae-polarity*(ve**2+ae**2))*(PZ**2)*2.*vu*au !Z
            B_d = (-ae+polarity*ve)*PZ*2.*edq*ad 
     $           + (2.*ve*ae-polarity*(ve**2+ae**2))*(PZ**2)*2.*vd*ad



         endif



cv for polarised case should reduce to:
cv         A_u = e2u - ve*PZ*2.*euq*vu +(ve**2 + ae**2)*PZ**2*(vu**2+au**2)
cv         A_d = e2d - ve*PZ*2.*edq*vd +(ve**2 + ae**2)*PZ**2*(vd**2+ad**2)
cv         B_u = -ae*PZ*2.*euq*au + 2.*ve*ae*(PZ**2)*2.*vu*au
cv         B_d = -ae*PZ*2.*edq*ad + 2.*ve*ae*(PZ**2)*2.*vd*ad

C Get x-sections:
         yplus  = 1+(1-y(i))**2
         yminus = 1-(1-y(i))**2

C
C xF3, F2, FL from QCDNUM:
C
         XF3  = B_U*XF3p(i)  + B_D*XF3m(i)
         F2   = A_U*F2p(i)   + A_D*F2m(i)
         FL   = A_U*FLp(i)   + A_D*FLm(i)


C-----------------------------------------------------------------------
C  Extra heavy flavour schemes
C


c
C ACOT scheme 
C                     
         if (mod(HFSCHEME,10).eq.1) then
            call sf_acot_wrap(x(i),q2(i),
     $           f123l,f123lc,f123lb,
     $           hfscheme, 4, 
     $           iFlagFCN, idx,
     $           UseKFactors)
            
            FL  = F123L(4)
            F2  = F123L(2)
            
            if (charge.gt.0) then
               XF3 = - x(i)*F123L(3)
            else
               XF3 = x(i)*F123L(3)
            endif

C RT scheme 
C            
         elseif (mod(HFSCHEME,10).eq.2) then 


C RT does not provide terms beyond gamma exchange. Since they occur at high Q2,
C use QCDNUM to take them into account as a "k"-factor 
C
C  F2_total^{RT} =  F2_{\gamma}^{RT}  *  (  F2_{total}^{QCDNUM}/F2_{\gamma}^{QCDNUM}   
C

           F2Gamma = 4.D0/9.D0 * F2p(i)  + 1.D0/9.D0 * F2m(i)
           FLGamma = 4.D0/9.D0 * FLp(i)  + 1.D0/9.D0 * FLm(i)


           call sfun_wrap(x(i),q2(i)
     $          ,f2pRT,flpRT,f1pRT,
     +          rpRT,f2nRT,flnRT,
     +          f1nRT,rnRT,f2cRT,
     +          flcRT,f1cRT,f2bRT,
     +          flbRT,f1bRT
           ! Input:
     $          ,iFlagFCN,idx    ! fcn flag, data point index
     $          ,F2Gamma,FLGamma
     $          ,UseKFactors
     $          )
           

           F2rt = F2pRT * (F2/F2Gamma)
           FLrt = FLpRT * (FL/FLGamma)


C Replace F2,FL from QCDNUM by RT values
C Keep xF3 from QCDNUM

           F2 = F2rt
           FL = FLrt
        endif
            

C FFNS, heavy quark contribution (c and b) to F2 and FL   
        if (mod(HFSCHEME,10).eq.3) then 

c           write(6,*) 'FFNS before sum: F2', i,F2
           F2 = F2 + F2c(i) + F2b(i) 
           FL = FL + FLc(i) + FLb(i)
c           write(6,*) 'FFNS: F2,F2c,F2b', i,F2,F2c(i),F2b(i)

        endif
         

C polarisation already taken into account in the couplings (A_q,B_q)

        XSec(i) = F2 + yminus/yplus*xF3 - y(i)*y(i)/yplus*FL

cv to get back to the old unpolarised case then one has to uncomment this:
cv        if (charge.gt.0) then
cv
cv           XSec = F2 - yminus/yplus*xF3 - y(i)*y(i)/yplus*FL
cv
cv       else
cv           XSec = F2 + yminus/yplus*xF3 - y(i)*y(i)/yplus*FL
cv        endif

      enddo
      end




