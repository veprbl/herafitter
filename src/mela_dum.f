c----------------------------------------------------------
c     this file contains dummy MELA interface routines
c     which are called in case HERAfitter was not compiled
c     with --enable-mela option
c----------------------------------------------------------
      subroutine mela_ini
      call print_apfel_error_message
      return 
      end

      subroutine print_mela_error_message
      print *, '--------------------------------------------------'
      print *, 'MELA: You have chosen to use MELA but HERAfitter'
      print *, 'is not compiled with --enable-mela option.'
      call exit(-10)
      return 
      end

      subroutine readparameters
      call print_mela_error_message
      end

      subroutine SetHERAFitterParametersMELA
      call print_mela_error_message
      end