module m_moment_fitting
  use parameters
  implicit none
contains
  
  subroutine estimate_parameters_gaussian(mom2, mom4, omega_out, alpha_out, alpha_f_out, fwhm_f_out)
    implicit none
    real(kind=wp), intent(in):: mom2, mom4
    real(kind=wp), intent(out):: omega_out, alpha_out, alpha_f_out, fwhm_f_out
    
    real(kind=wp):: p, q, omega1, omega2, alpha1, alpha2, alpha1_f, &
         alpha2_f, fwhm1_f, fwhm2_f, om(100000), func(100000),&
         mom0
    integer::i
    
    ! estimate parameters in \cos(\omega_0 t) e^{-\alpha_0 t^2}
    !b = -18.0_wp / 13.0_wp * derivative2_tot
    !c = (6.0_wp * derivative2_tot - derivative22_tot) / 13.0_wp 
    
    p = -mom2  
    q = (mom4 - mom2 ** 2) / 8.0_wp
    
    if(p **2 / 4 .lt. q ) then
      write(6,*) "problem with fitting, complex roots!"
    else
      ! first root
      alpha1 = -p / 2.0_wp + sqrt((p **2) / 4.0_wp - q)
      ! second root
      alpha2 = -p / 2.0_wp - sqrt((p **2) / 4.0_wp - q)
    end if
    
    omega1 = sqrt(mom2 -2.0_wp * alpha1 ) 
    
    alpha1_f = 1.0_wp / (4.0_wp * alpha1 ) !* energy_scale**(-2.0_wp)    
    fwhm1_f = 2.0_wp * sqrt(log(2.0_wp) / alpha1_f) 
    
    omega2 = sqrt(mom2 -2.0_wp * alpha2 ) 
    alpha2_f = 1.0_wp / (4.0_wp * alpha2 )
    fwhm2_f = 2.0_wp * sqrt(log(2.0_wp) / alpha2_f)
    
    !write(6,*) "fitted first root, omega:", omega1  ,"alpha", alpha1 
    !write(6,*) "alpha' in fourier space",   alpha1_f, "fwhm", fwhm1_f
    
    !write(6,*) "fitted second root, omega:", omega2  ,"alpha", alpha2 
    !write(6,*) "alpha' in fourier space",   alpha2_f, "fwhm", fwhm2_f
    
    omega_out = omega2
    alpha_out = alpha2
    alpha_f_out = alpha2_f
    fwhm_f_out = fwhm2_f
    
  end subroutine estimate_parameters_gaussian
  
  subroutine estimate_parameters_lorentzian(mom2, mom4, omega_out, Gamma_out, fwhm_freq_out)
    implicit none
    real(kind=wp), intent(in):: mom2, mom4
    real(kind=wp), intent(out):: omega_out, Gamma_out, fwhm_freq_out
    
    real(kind=wp):: p, q, omega1, omega2, alpha1, alpha2, alpha1_f, &
         alpha2_f, fwhm1_f, fwhm2_f, om(100000), func(100000),&
         mom0
    integer::i
    
    p = -8.0_wp * mom2 / (mom4 -mom2 ** 2)
    q = -4.0_wp / (mom4 -mom2 ** 2)

    if(p **2 / 4.0_wp .lt. q ) then
       write(6,*) "problem with fitting, complex roots!"
    else
    
      ! first root
      alpha1 = -p / 2.0_wp + sqrt((p **2) / 4.0_wp - q)
      ! second root
      alpha2 = -p / 2.0_wp - sqrt((p **2) / 4.0_wp - q)
    end if
    
    omega1 = sqrt(mom2 -2.0_wp / alpha1 ) !* energy_scale       
    omega2 = sqrt(mom2 -2.0_wp / alpha2 ) !* energy_scale       

    !write(6,*) "fitted first root, omega:", omega1  ,"Gamma", sqrt(alpha1), "fwhm in freq", 2.0_wp * log(2.0_wp) / sqrt(alpha1) !* energy_scale     
    !write(6,*) "alpha' in fourier space",   alpha1_f, "fwhm", fwhm1_f

    !write(6,*) "fitted second root, omega:", omega2  ,"Gamma", sqrt(alpha2), "fwhm in freq", 2.0_wp * log(2.0_wp) / sqrt(alpha2) !* energy_scale      
    !write(6,*) "alpha' in fourier space",   alpha2_f, "fwhm", fwhm2_f

    omega_out = omega1
    Gamma_out = sqrt(alpha1)
    fwhm_freq_out = 2.0_wp * log(2.0_wp) / sqrt(alpha1)    
    
  end subroutine estimate_parameters_lorentzian
  
  subroutine cont_fraction_parameters(mom2, mom4, mom6, d1,d2,d3)
    implicit none
    real(kind=wp), intent(in)::  mom2, mom4, mom6
    real(kind=wp), intent(out):: d1,d2,d3
    
    d1 = mom2
    d2 = mom4 / mom2 -mom2
    d3 = (1.0_wp / d2 ) * (mom6 / mom2 - (mom4 /mom2)**2)
    
  end subroutine cont_fraction_parameters
  
end module m_moment_fitting
