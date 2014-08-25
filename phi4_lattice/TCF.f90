program TCF
  use parameters
  use m_hist
  use FFT_m
  use m_TCF
  use m_system_3d
  use m_strings
  !use m_symmetry
  implicit none

  character(80):: infile, outfile, units, file, string, filename
  integer:: ntsteps, nparticles, ndisp
  integer:: nqpoints_inp, nqpoints2, nqpoints
  real(kind=wp), allocatable:: qpoints_inp(:,:), qpoints(:,:)

  real(kind=wp), allocatable:: time(:), x(:), v(:), a(:), t_new(:) 
  real(kind=wp),allocatable:: omega(:)
  
  complex(kind=wp), allocatable:: qpt_x(:,:,:), qpt_v(:,:,:), qpt_a(:,:,:), qpt_vH(:,:), tcf2(:,:,:), a_q(:)
  real(kind=wp), allocatable:: ft_tcf_real(:,:,:), ft_tcf_imag(:,:,:) 
  complex(kind=wp), allocatable:: ft_tcf(:,:,:), ft_tcf_a_q(:)

  integer:: cellnum, cell(3), supercell(3)
  integer:: i,j,k, n, q, j1,j2 
  integer:: npoints_pad, npoints_pad_pow, n_autocorr
  real(kind=wp):: qp(3), qp2(3), vec(3), qpoint(3)
  real(kind=wp):: alpha, xl, dt, fwhm, cell_a
  logical:: flag_tcf_x, flag_tcf_v, flag_tcf_a, flag_vanHove

  ! the program computes time correlation functions and their fourier transforms
  ! using output generated by the four_phi_model_3d program
  
  ! read input
  read(5,*) infile
  read(5,*) outfile
  read(5,*) ntsteps
  read(5,*) fwhm
  read(5,*) units
  read(5,*) flag_tcf_x, flag_tcf_v, flag_tcf_a, flag_vanHove  
  read(5,*) nqpoints_inp, nqpoints2 

  allocate(qpoints_inp(nqpoints_inp,3))
  do i=1,nqpoints_inp
     read(5,*) qpoints_inp(i,:)
  end do 

  cell_a= 2.5_wp

  ! make the path in q-space
  nqpoints = (nqpoints_inp -1) * nqpoints2 +1
  allocate(qpoints(nqpoints,3)) !, band(nqpoints,3))
  
  n=1
  do i=1, nqpoints_inp-1
     vec = qpoints_inp(i+1,:) - qpoints_inp(i,:) 
     
     do j=1,nqpoints2
        qpoints(n,:) = qpoints_inp(i,:) + (dfloat(j-1) / nqpoints2) * vec
        n=n+1
     end do
  end do
  qpoints(nqpoints,:) = qpoints_inp(nqpoints_inp,:)
  
  n_autocorr = ntsteps  !/ 2
  
  allocate(time(ntsteps), t_new(n_autocorr) )
  
  open(10, file=infile, status="unknown", form="UNFORMATTED")
  
  ! read files
  do k=1, ntsteps     
     write(6,*) "Reading input file, step", k
     
     read(10) supercell, time(k)
     
     if (.not. allocated(x) ) then
        nparticles = product(supercell)
        ndisp = nparticles*3
        
        call allocate_things
        
     end if
     
     read(10)
     do j=1, nparticles
        read(10) x(3*(j-1)+1:3*(j-1)+3), v( 3*(j-1)+1:3*(j-1)+3), a(3*(j-1)+1:3*(j-1)+3)        
     end do ! j

     call get_q_space_all

  end do ! k
  
  close(10)
  
  ! new time for autocorr functions
  t_new=0.0_wp
  do i=1, n_autocorr
     t_new(i) = time(i)
  end do

  ! for fourier transform 
  call next_power_of_2(n_autocorr, npoints_pad, npoints_pad_pow)

  allocate(omega(npoints_pad))

  ! Omega
  dt = time(2)-time(1)
  xl = (npoints_pad-1) * dt
  do i =1, npoints_pad
     !omega(i) = 2 * pi * (i-1) / xl * (hbar /eV)  ! eV
     omega(i) = 2 * pi * (i-1) / xl !* (hbar * cm)  ! cm-1
  end do
  
  if(units .eq. "cm-1") then
     omega = omega * (hbar * cm)
  end if
  
  ! alpha = (fwhm  / (cm *hbar) ) ** 2 / (16.0_wp * log(2.0_wp) )  ! cm-1
  alpha = (fwhm ) ** 2 / (16.0_wp * log(2.0_wp) )  ! cm-1
  
  ! compute q-space TCF
  allocate(ft_tcf_real(npoints_pad,3,3), ft_tcf_imag(npoints_pad,3,3), tcf2(n_autocorr,3,3), ft_tcf(npoints_pad,3,3)  )
  allocate(ft_tcf_a_q(npoints_pad), a_q(n_autocorr))
  
  do q=1, nqpoints
    qpoint = qpoints(q,:)
     if(flag_tcf_x) then

        ! neutron scattering
        a_q = 0.0_wp
        do j1=1,3
           a_q = a_q + qpoints(q,j1) * qpt_x(q,:,j1)
        end do

        !call atenuate_gaussian(a_q, t_new, alpha)
           
        call q_space_TCF_FFT(a_q, ft_tcf_a_q)

        filename="ft_tcf_a_q" 
        call string_int_concatenate(filename,q)
        call string_string_concatenate(filename,".dat")     
        call write_file(filename, qpoints(q,:), dreal(ft_tcf_a_q), omega )        

        ! IR:  <P(t)P(0)> ~ <(sum_i x_i(t))(sum_i j_j(x_j))
        ! Raman:  <\alpha(t) \alpha(0)> ~ <(sum_i x_i(t))(sum_i j_j(x_j))>

        call calculate_TCF(qpt_x(q,:,:), t_new, ft_tcf)
        call write_TCF("ft_tcf_x",  ft_tcf, q, qpoint, omega)

     end if

     if(flag_tcf_v) then
        call calculate_TCF(qpt_v(q,:,:), t_new, ft_tcf)        
        call write_TCF("ft_tcf_v",  ft_tcf, q, qpoint, omega)
     end if

     if(flag_tcf_a) then
        call calculate_TCF(qpt_a(q,:,:), t_new, ft_tcf)
        call write_TCF("ft_tcf_a",  ft_tcf, q, qpoint, omega)
     end if
        
     if(flag_vanHove) then

        a_q =  qpt_vH(q,:)
        !call atenuate_gaussian(a_q, t_new, alpha)
        
        call q_space_TCF_FFT(a_q, ft_tcf_a_q)

        filename="ft_tcf_vH" 
        call string_int_concatenate(filename,q)
        call string_string_concatenate(filename,".dat")     
        call write_file(filename, qpoints(q,:), dreal(ft_tcf_a_q), omega )        

     end if

  end do

contains

subroutine get_q_space_3(supercell, x_inp, qp, q_out)
  integer,intent(in):: supercell(3)
  real(kind=wp), intent(in) :: x_inp(:)
  real(kind=wp), intent(in) :: qp(3)
  complex(kind=wp), intent(out):: q_out(3)

  integer:: i,ii

  nparticles = product(supercell)
  
  do i=0, nparticles-1

     ii = 3 * i
     call cellnum_to_cell(supercell, i, cell)

     q_out = q_out + x_inp(ii + 1: ii +3) * &
          exp(dcmplx(0, 2.0_wp * pi * dot_product(qp, dfloat(cell))   ) )
  end do

end subroutine get_q_space_3


subroutine get_q_space_vanHove(supercell, x_inp, qp, q_out)
  integer,intent(in):: supercell(3)
  real(kind=wp), intent(in) :: x_inp(:)
  real(kind=wp), intent(in) :: qp(3)
  complex(kind=wp), intent(out):: q_out

  integer:: i,ii

  nparticles = product(supercell)
  
  do i=0, nparticles-1

     ii = 3 * i
     call cellnum_to_cell(supercell, i, cell)

     q_out = q_out + &
          exp(dcmplx(0,  2.0_wp * pi * dot_product(qp, x_inp(ii + 1: ii +3) / cell_a + dfloat(cell)) ) ) !-1.0_wp
  end do

end subroutine get_q_space_vanHove


subroutine allocate_things

  allocate(x(ndisp), v(ndisp), a(ndisp) )

  allocate(qpt_x(nqpoints, ntsteps,3), &
       qpt_v(nqpoints, ntsteps,3), &
       qpt_a(nqpoints, ntsteps,3), &
       qpt_vH(nqpoints, ntsteps))

end subroutine allocate_things


subroutine get_q_space_all
  integer:: q
  real(kind=wp):: qp(3)

  do q=1, nqpoints
     qp = qpoints(q,:)  
     !qp2 = -qp 

     call get_q_space_3(supercell, x(:), qp, qpt_x(q,k,:))
     call get_q_space_3(supercell, v(:), qp, qpt_v(q,k,:))
     call get_q_space_3(supercell, a(:), qp, qpt_a(q,k,:))
     call get_q_space_vanHove(supercell, x(:), qp, qpt_vH(q,k))
     
  end do ! q

end subroutine get_q_space_all

!subroutine symmetrize_all
!
!  if(sym_flag) then
!    
!    if(symmetry .eq. "cubic") then
!      
!      write(6,*) "Using cubic symmetry"
!      allocate(Mat_symm(3,3,48))
!      call get_cubic_symm(Mat_symm)
!      
!    else if(symmetry .eq. "tetragonal") then
!      
!      write(6,*) "Using tetragonal symmetry around axis", sym_axis
!      allocate(Mat_symm(3,3,8))
!      call get_tetragonal_symm(Mat_symm,sym_axis)
!    else
!      write(6,*) "Error, symmetry must be either 'cubic' or 'tetragonal'"
!      stop
!    end if
!    
!    do q=1,nqpoints
!      do i=1,size(qpt_x,2)
!        call symmetrize_1_complex(qpt_x(q,i,:), Mat_symm)
!        call symmetrize_1_complex(qpt_v(q,i,:), Mat_symm)
!        call symmetrize_1_complex(qpt_a(q,i,:), Mat_symm)
!      end do
!    end do
!    
!  else
!    write(6,*) "Not using symmetry"
!    
!  end if
!
!end subroutine symmetrize_all
!
!subroutine get_symmetry_matrix
!  
!  if(sym_flag) then
!    
!    if(symmetry .eq. "cubic") then
!      
!      write(6,*) "Using cubic symmetry"
!      allocate(Mat_symm(3,3,48))
!      call get_cubic_symm(Mat_symm)
!      
!    else if(symmetry .eq. "tetragonal") then
!      
!      write(6,*) "Using tetragonal symmetry around axis", sym_axis
!      allocate(Mat_symm(3,3,8))
!      call get_tetragonal_symm(Mat_symm,sym_axis)
!    else
!      write(6,*) "Error, symmetry must be either 'cubic' or 'tetragonal'"
!      stop
!    end if
!  
!  else
!    write(6,*) "Not using symmetry"
!  end if
!
!end subroutine get_symmetry_matrix
!
!subroutine symmetrize_TCF(ft_tcf, Mat_symm)
!  real(kind=wp), intent(inout):: ft_tcf(:,:,:)
!  real(kind=wp), intent(in):: Mat_symm(:,:,:)
!
!  integer:: i
!
!  do i=1,size(ft_tcf,1)
!    call symmetrize_2(ft_tcf(i,:,:), Mat_symm)
!  end do
!     
!end subroutine symmetrize_TCF

end program TCF
