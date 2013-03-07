      subroutine Generate_IO_FileNames
C======================================================================
C
C 2 Oct 2011: add extra parameters before starting minuit
C WS: modified to have different file names for the offset method
C
C----------------------------------------------------------------------
      implicit none
      include 'steering.inc'
      include 'ntot.inc'
      include 'systematics.inc'
      include 'iofnames.inc'

      ! character*72 ResultsFile
      ! character*72 MinuitIn
      ! character*72 MinuitOut
      ! character*72 MinuitSave      
      ! common/io_Fnames/ResultsFile,MinuitIn,MinuitOut,MinuitSave
      
      character*32 Suffix
      character*72 AltInp
      character*32 OffsLabel
      logical file_exists
      ! .............................

      call flush(6)
      if(doOffset) then
        Suffix='_'//OffsLabel(CorSysIndex,'.txt')
      else
        Suffix = '.txt'
      endif
      
      ResultsFile = 'output/Results'//Suffix
      MinuitOut = 'output/minuit.out'//Suffix
      MinuitSave = 'output/minuit.save'//Suffix

      MinuitIn='minuit.in.txt' 
      if(UsePrevFit .ge. 1) then
        AltInp = 'output/minuit.save'//Suffix
        INQUIRE(FILE=AltInp, EXIST = file_exists)
        if(.not.file_exists .and. doOffset) then
          ! --- try to use the central fit results
          AltInp = 'output/minuit.save'//'_'//OffsLabel(0,'.txt')
          INQUIRE(FILE=AltInp, EXIST = file_exists)
        endif
        if(file_exists) then
          ! --- Change parameters acc. to the found minuit-saved file
          ! Call MntInpRead(Trim(MinuitIn)//CHAR(0))
          ! Call MntInpReadPar(Trim(AltInp)//CHAR(0))
          Call MntInpRead(MinuitIn,"tpc",1)
          Call MntInpRead(AltInp,"p",1)
          MinuitIn='minuit.temp.in.txt' 
          ! Call MntInpWrite(Trim(MinuitIn)//CHAR(0))
          Call MntInpWrite(MinuitIn)
          Call MntInpFixXtra
        endif
      endif

      return
      end

      subroutine minuit_ini
C======================================================================
C
C 2 Oct 2011: add extra parameters before starting minuit
C 2012-11-03 WS: modified to just open MINUIT i/o files with names
C                generated by Generate_IO_FileNames
C
C----------------------------------------------------------------------
      implicit none
      include 'steering.inc'
      include 'iofnames.inc'

      open ( 25, file=MinuitOut )
      
      write(6,*) ' read minuit input params from file ',MinuitIn
      call HF_errlog(12020504, 'I: read minuit input params from file '//MinuitIn)
      open ( 24, file=MinuitIn )

      open (  7, file=MinuitSave)
      
      call mintio(24,25,7)
      
      return
      end

      
      Subroutine Do_Fit
C======================================================================
C
C Perform the fit
C Shift the data by Correlated Sources for the Offset method
C
C----------------------------------------------------------------------

      implicit none
      include 'ntot.inc'
      include 'steering.inc'
      include 'datasets.inc'
      include 'systematics.inc'
      include 'indata.inc'
      include 'for_debug.inc'
      ! include 'theo.inc'
      include 'fcn.inc'
      ! include 'endmini.inc'
      include 'extrapars.inc'
      include 'iofnames.inc'

      Logical FileExists
      external fcn

      integer amu
      integer OffsetIndex
      double precision daten_notshifted(NTOT)
      double precision musign
      character*32 OffsLabel

      integer j
      integer IERFLG
      ! .......................................

      Call Generate_IO_FileNames
      
      if(UsePrevFit.eq.2 .and. FileExists(ResultsFile)) then
        print *,'==>  Using previous fit results.'
        return
      endif
      
      print *,'==>  Starting the fit...'
      print *,'ResultsFile = ',ResultsFile
      print *,'MinuitIn = ',MinuitIn
      print *,'MinuitOut = ',MinuitOut
      print *,'MinuitSave = ',MinuitSave
      
      if(doOffset .and. CorSysIndex .ne. 0) then
        if(IABS(CorSysIndex) .gt. nSys) then
          print *,' CorSysIndex out of range'
          call HF_errlog(12110601, 'F: CorSysIndex out of range') 
        endif
        ! --- store original data
        do j=1,npoints
          daten_notshifted(j) = daten(j)
        enddo
        ! --- shift by CorSysIndex
        amu = OffsetIndex(IABS(CorSysIndex))
        ! write(*,*)'--> OFFSET CorrSrc = ',amu
        musign = ISIGN(1,CorSysIndex)
        do j=1,npoints
          daten (j) = daten_notshifted(j)*(1 + musign*beta(amu,j))
        enddo
      endif

*     ------------------------------------------------
*     Do the fit
*     ------------------------------------------------

      OPEN(85,file=ResultsFile,form='formatted',status='replace')
      ! write(*,*) 'ResultsFile: ',ResultsFile
      call minuit_ini  ! opens Minuit i/o files
      lprint = .true.
c      lprint = .false.
      ! Call ShowXPval(2)
      call minuit(fcn,0)
      call flush(6)
      if(doOffset) then
        Call MntInpRead(MinuitIn,"c",0)
        ! --- Force HESSE to have accurate cov. matrix
        ! --- not necessary for non-central Offset fits, so do not put it in your minuit input
        if(CorSysIndex .eq. 0) then
          Call MntInpHasCmd("hesse",IERFLG)
          if(IERFLG.eq.0) then
            print *,' '
            print *,'==> Forcing HESSE for CorSysIndex 0'
          endif
          call MNCOMD(fcn,'hesse',IERFLG,0)
        endif
        ! --- force level 3 SAVE
        Call MntInpHasCmd("save",IERFLG)
        if(IERFLG.ne.0) Call MntInpHasCmd("set print 3",IERFLG)
        if(IERFLG.eq.0) then
          ! print *,'Minuit SAVE'
          call MNCOMD(fcn,'set print 3',IERFLG,0)
          Call MNSAVE
        endif
      endif
      close(85)
*     ------------------------------------------------
       
      call flush(6)
      if(doOffset) then
        ! --- In the non-Offset mode these io units are used in main.f for DOBANDS 
        ! --- via MNCOMD to ITERATE and MYSTUFF 
        close(24)
        close(25)
        close(7)
        call Offset_SaveParams(CorSysIndex)
        Call MntInpGetParams
        Call MntInpWritePar('output/MI_saved'//'_'//OffsLabel(CorSysIndex,'.txt'))
        if(CorSysIndex .eq. 0) then
          call Offset_SaveStatCov
        else
          ! --- restore original (unshifted) data
          do j=1,npoints
             daten(j) = daten_notshifted(j)
          enddo
        endif
      endif
         
      return
      end

      
      subroutine ExtraParam
C======================================================================
C
C MINUIT module 'minuit.F' is modified
C to call ExtraParam after reading parameters
C
C----------------------------------------------------------------------
      implicit none
      include 'extrapars.inc'
      integer i, ierrf

C Add extra parameter:

      do i = 1,nExtraParam
         call mnparm(100+i,ExtraParamNames(i)
     $        ,ExtraParamValue(i)
     $        ,ExtraParamStep(i)
     $        ,ExtraParamMin(i)
     $        ,ExtraParamMax(i)
     $        ,ierrf)
         if (ierrf.ne.0) then
            print *,'Error adding extra parameter',i
            print *,'name, value, step, min, max are:',
     $           ExtraParamNames(i)
     $        ,ExtraParamValue(i)
     $        ,ExtraParamStep(i)
     $        ,ExtraParamMin(i)
     $        ,ExtraParamMax(i)
            print *,'Error code=',ierrf
            call HF_errlog(12020505,'F: Error in ExtraParam')
         else
            iExtraParamMinuit(i) = 100+i
         endif
      enddo
      end

      
      Logical Function FileExists(FileName)
C====================================================
C
C  WS 2012-11-02
C  Return: does FileName exist?
C
C----------------------------------------------------
      implicit none
      character*(*) FileName
      logical file_exists
      INQUIRE(FILE=FileName, EXIST = file_exists)
      ! print *,' --- FileExists: ',FileName,file_exists
      FileExists = file_exists
      return
      end
      
      
      CHARACTER*(*) FUNCTION OffsLabel(mu, tail)
C ==================================================
C
C 2012-06-25 WS
C Generate trailing part of an output file name
C
C---------------------------------------------------
      implicit none
      integer mu
      character*(*) tail
      integer amu,smu,ndig
      parameter(ndig=3) ! as NSYSMAX = 300
      character str*(ndig)
      character*8 fmt
      character*2 mp
      parameter(mp = 'mp')
      
      if(mu.eq.0) then
        OffsLabel = '0' // tail
        return
      end if
      
      smu = (ISIGN(1,mu)+1)/2 +1
      amu = IABS(mu)
      write(fmt,'(a,i1,a,i1,a)') '(i',ndig,'.',ndig,')'
      write(str,fmt) amu
      OffsLabel = str // mp(smu:smu) // tail
      return
      end

