module m_FFT
  use parameters
  implicit none
  interface
     SUBROUTINE SFFTEU( X, Y, N, M, ITYPE )
       INTEGER  N, M, ITYPE
       REAL(8)  X(*), Y(*)
     END SUBROUTINE SFFTEU
  end interface
contains

  subroutine next_power_of_2(n, m, pow)
    integer, intent(in):: n
    integer, intent(out):: m,pow
    
    integer:: i
    
    do i=1,1000
       if( 2 ** i .ge. n) then
          pow = i
          exit
       end if
    end do
    
    m = 2 ** pow
  end subroutine next_power_of_2
  
  subroutine reorder_sigma1(sigma)
    real(kind=wp), dimension(:), intent(inout)::sigma

    integer::nfreq
    integer:: i,j
    integer, dimension(1)::dime
    real(kind=wp), dimension(:), allocatable::sigma_tmp
    
    dime= shape(sigma)
    nfreq = dime(1)

    allocate(sigma_tmp(nfreq))
    
    j=1
!    do i=nfreq/2, 1, -1
    do i=nfreq/2 + 1, nfreq !1, -1
       sigma_tmp(j) = sigma(i) 
       j=j+1
    end do
    
!    do i=0, nfreq/2 -1
    do i=1, nfreq/2 
       sigma_tmp(j) = sigma(i) 
       j=j+1     
    end do
    
    sigma=sigma_tmp

  end subroutine reorder_sigma1


subroutine FFT_complex(x, f, f_out, omega)
  real(kind=wp), intent(in), dimension(:)::x
  complex(kind=wp), intent(in), dimension(:):: f
  complex(kind=wp), intent(out), dimension(:):: f_out
  real(kind=wp), intent(out), dimension(:)::omega

  real(kind=wp), dimension(:),allocatable:: f_real, f_imag, f_out_real, f_out_imag
  real(kind=wp):: x_l
  integer:: npoints, npoints_pad, npoints_pad_pow, i,j

  npoints = size(x)

  call next_power_of_2(npoints, npoints_pad, npoints_pad_pow)

  if(npoints .ne. size(f) &
       .or. npoints_pad .ne. size(f_out) &
       .or. npoints_pad .ne. size(omega) ) then
     write(6,*) "error in FFT_complex", npoints, size(f_out), size(omega)
     stop
  end if
  

  allocate(f_real(npoints), f_imag(npoints), f_out_real(npoints_pad), f_out_imag(npoints_pad))

  f_real = dreal(f)
  f_imag = dimag(f)

  call FFT(f_real, f_imag, f_out_real, f_out_imag, -1)

  !call reorder_sigma1(f_out_real)
  !call reorder_sigma1(f_out_imag)

  f_out = dcmplx(f_out_real, f_out_imag)

  x_l = (x(2)-x(1)) * (npoints_pad-1) 

  j=1  
  do i=npoints_pad/2, 1, -1
     omega(j) = -2 * pi * i  / x_l 
     j=j+1
  end do
  do i=0, npoints_pad/2 -1
     omega(j) =  2 * pi * i / x_l 
     j=j+1
  end do

  deallocate(f_real, f_imag, f_out_real, f_out_imag )

end subroutine FFT_complex


subroutine FFT_real(x, f, f_out_real, f_out_imag, omega_out)
  real(kind=wp), intent(in), dimension(:)::x,f
  real(kind=wp), intent(out), dimension(:)::f_out_real, f_out_imag,omega_out

  complex(kind=wp), dimension(:), allocatable:: f_compl_in, f_compl_out
  real(kind=wp):: x_l
  integer:: npoints, npoints_pad, i

  npoints = size(x)

  if(npoints .ne. size(f) &
       .or. npoints .ne. size(f_out_real) &
       .or. npoints .ne. size(f_out_imag) &
       .or. npoints .ne. size(omega_out) ) then
     write(6,*) "error in FFT_real"
     stop
  end if
 
  allocate(f_compl_in(npoints), f_compl_out(npoints))

  f_compl_in = dcmplx(f)
  
  call FFT_complex(x,f_compl_in, f_compl_out, omega_out)

  f_out_real = dreal(f_compl_out)
  f_out_imag = dimag(f_compl_out)

  deallocate(f_compl_in, f_compl_out)
 
end subroutine FFT_real



subroutine FFT(f_real, f_imag, f_out_real, f_out_imag, itype)
  real(kind=wp), intent(in), dimension(:)::f_real,f_imag
  real(kind=wp), intent(out), dimension(:)::f_out_real,f_out_imag
  integer, intent(in):: itype
  
  integer:: npoints, npoints_pad, npoints_pad_pow, i
  
  npoints = size(f_real)
  
  if(npoints .ne. size(f_imag)) then
     write(6,*) "error in FFT"
     stop
  end if

  call next_power_of_2(npoints, npoints_pad, npoints_pad_pow)
  
  if(npoints_pad .ne. size(f_out_real) &
       .or. npoints_pad .ne. size(f_out_imag)) then
     write(6,*) "error in dimension in FFT, output for input dimension", npoints, &
          "must be", npoints_pad, "= 2 **", npoints_pad_pow 
     stop
  end if
  
  f_out_real = 0
  f_out_real(1:npoints) =f_real(1:npoints)
  f_out_imag = 0
  f_out_imag(1:npoints) =f_imag(1:npoints)
  
  call SFFTEU( f_out_real, f_out_imag, npoints_pad, npoints_pad_pow, itype)
  
end subroutine FFT

end module m_FFT
