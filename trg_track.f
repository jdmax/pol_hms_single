*------------------------------------------------------------------------
*
*       TRG_TRACK  GEN Target Rracking routines 
*      -=========-
* 
*	Raytracing of 3-d motion in polarized target field by solution
*	of differential equations of motion via 4th order Runge-Kutta. Field 
*	orientation arbitrary. 
*
*       Note: - the HMS routines use a right handed coord. system with
*                 x : pointing downwards
*                 y : perpendicular to x,z, 
*                     pointing to the left (if seen in z-direction)
*                 z : BEAM axis or HMS axis, pointing downstream or 
*                     from the target to the focal plane respectively
*
*             - the B field map uses a cylindrical coordinate system
*               with z along the field axis and r perpendicular to it
*
*             - all length (x,y,z,dl,l,...) are measured in [cm]
*             - all velocities are measured in [cm/ns]
*             - all angles are measured counter clock wise in [deg]
*             - time is measured in [ns] 
*             - the B field is measured in [T]
* 
*       original devloped by ???
*       widely modified by MM 
*         - converted into subroutines  
*         - rotation algorytm correced (at moment: phi==0 assumed)
*         - changed coordinate system 
*             beam direction:   z
*             horizontal plane: zy
*             out of plane:     x  (points downwards) 
*
*       Supplies:
*         trgInit (map,theta,phi) 
*           load the target field map
*         trgTrackToPlane (u,E,dl,a,b,c,d,ok)
*            track a single particle with given start parameters
*            and find the intersection of the particle track with 
*            a given plane
*       
*       Note: - Before calling trgTrack,trgXTrack or trgTrackToPlane
*               the target field map has to be loaded by a call to 
*               trgInit
*
*       99/11/24 GAW: in trgInit - fixed bug in uniform field
*                                - added zero field option
*                     in trgTrackToPlane - fixed bug in which routine took 
*                                 an extra step if crossed the targeted plane
*                                 in the first step
*      99/12/06 GAW: numerous modifications to work with 2 spectrometers
*------------------------------------------------------------------------
   

 
      SUBROUTINE trgTrackToPlane (u,E,dl,a,b,c,d,ok,spect)
      IMPLICIT NONE
!      REAL*8    u(6),E,dl,a,b,c,d
      REAL*8    u(9),E,dl,a,b,c,d	!	OR - 4/04
      INTEGER spect
      LOGICAL ok
* --  track a single particle with given start parameters
*     and find the intersection of the particle track with a given plane
*
*     Parameter:
*        u     IO : coordinate vector (initial/final)
*                     u0(1,2,3) : x, y, z [cm]
*                     u0(4,5,6) : dx/dt, dy/dt, dz/dt [cm/ns] 
*        E     I  : particle energy [MeV] * sign of particle charge
*                   (negative for electrons, positive for protons/deuterons)
*        dl    I  : step size [cm]
*        a..d  I  : parameter of the intersection plane 
*                   0 = a*x+b*y+c*z+d; 
*        ok    IO : status variable 
*                   - if false no action is taken 
*                   - set to false when no intersection point is found 
*                    
                 
      REAL*8   factor
      COMMON /trgConversionFactor/factor

!      REAL*8    ts,n,an,bn,cn,dn,maxdist,dist0,dist1,u0(6),u1(6)
      REAL*8    ts,n,an,bn,cn,dn,maxdist,dist0,dist1,u0(9),u1(9)  !  OR - 4/04
       
      INTEGER i,steps,max_steps
      
!	For Bdl
	do i=7,9
	u(i)=0.0
	u0(i)=0.0
	u1(i)=0.0
	end do

      IF (.NOT. OK) RETURN   
        
      n  = 1.d00/SQRT (a*a+b*b+c*c)
      an = a*n
      bn = b*n
      cn = c*n
      dn = d*n
    
      factor =  90.d00/E
      ts     = -dl/sqrt(u(4)**2+u(5)**2+u(6)**2)


      dist0   = u(1)*an + u(2)*bn + u(3)*cn + dn
      maxdist = max(ABS(dist0)*4.d00,1.0d00)
      
      ! check for the tracking direction 
!      CALL trgRK4(u,u1,ts,spect)
      CALL trgRK4Bdl(u,u1,ts,spect)
      dist1 = u1(1)*an + u1(2)*bn + u1(3)*cn + dn  
      IF ((SIGN(1.D00,dist0) .EQ. SIGN(1.D00,dist1)) .AND.
     >    (ABS(dist0) .LT. ABS(dist1))) ts=-ts
         
      ! track through the intersection plane 
! GAW 99/11/22
! Previously, if dist1 and dist0 had different signs, it move the track one
! extra step so that interpolation in end is wrong.  The added if prevents that.
      steps = 0
      max_steps = int(max(dist0,10.*dl)/dl)*10
      IF (SIGN(1.D00,dist0).eq.SIGN(1.D00,dist1)) THEN
        dist1 = dist0   
        DO WHILE ((SIGN(1.D00,dist0) .EQ. SIGN(1.D00,dist1)) .AND. ok) 
!          CALL trgRK4(u1,u0,ts,spect)
        CALL trgRK4Bdl(u1,u0,ts,spect)
          dist0 = u0(1)*an + u0(2)*bn + u0(3)*cn + dn 
          IF (SIGN(1.D00,dist0) .EQ. SIGN(1.D00,dist1)) THEN
!            CALL trgRK4(u0,u1,ts,spect)
            CALL trgRK4Bdl(u0,u1,ts,spect)
            dist1 = u1(1)*an + u1(2)*bn + u1(3)*cn + dn  
          ENDIF
          ok = (ABS(dist1) .LT. maxdist).and.steps.lt.max_steps
C          write(*,*) dist0,dist1
          steps = steps+1
        ENDDO        
      ELSE
        DO i=1,6
          u0(i) = u(i)
        ENDDO
      ENDIF
      
      IF (ok) THEN        
        ! calculate the intersection point
        DO i=1,6
          u(i) = u0(i) + (u1(i)-u0(i)) * dist0/(dist0-dist1)
        ENDDO

!	Bdl

	do i=7,9
          u(i) = u0(i) + (u1(i)-u0(i)) * dist0/(dist0-dist1)
!	u(i)=u0(i)
	end do

      ENDIF
           
      RETURN
      END
	
*------------------------------------------------------------------------------
* load the field map and calculate the magnetic field strength  
* 
      SUBROUTINE trgInit (map,theta_e,phi_e,theta_p,phi_p)
      IMPLICIT NONE
      CHARACTER map*(*)
      REAL*8      theta_e,phi_e,theta_p,phi_p
* --  read field map (for calculations in the LAB system)
*
*     Parameter:
*        map        I : filename of the fieldmap (=' ': uniform field test case)
*        theta_e,phi_e I : inplane(theta) & out of plane(phi) angle for e spect
*        theta_p,phi_p I : inplane(theta) & out of plane(phi) angle for p spect
*        
*        note: currently phi is always treated as 0
*
* GAW 99/12/06 modified to work with 2 spectrometers

      INTEGER    nz,nr 
      PARAMETER (nz = 51)
      PARAMETER (nr = 51)

      REAL*8    B_field_z(nz,nr),B_field_r(nz,nr),zz(nz),rr(nr)
      REAL*8    B_theta_e,B_stheta_e,B_ctheta_e,B_phi_e,B_sphi_e,B_cphi_e 
      REAL*8    B_theta_p,B_stheta_p,B_ctheta_p,B_phi_p,B_sphi_p,B_cphi_p 
       
      COMMON  /trgFieldStrength/ B_field_z,B_field_r,zz,rr
      COMMON  /trgFieldAngles_e/ B_theta_e,B_stheta_e,B_ctheta_e,
     >                           B_phi_e,  B_sphi_e,  B_cphi_e 
      COMMON  /trgFieldAngles_p/ B_theta_p,B_stheta_p,B_ctheta_p,
     >                           B_phi_p,  B_sphi_p,  B_cphi_p 
 
      REAL*8       pi180
	real*8 scale	! hard coded rescaling of B field for RSS
	parameter (scale=0.98104)	! B_RSS = 5.0033 T - OARA 4/12/04
      PARAMETER (pi180 = 3.141592653d00/180.d00) 

      INTEGER ir,iz 
      REAL*8    xx
  
      B_theta_e  = theta_e
      B_stheta_e = SIN(theta_e*pi180) 
      B_ctheta_e = COS(theta_e*pi180)

      B_theta_p  = theta_p
      B_stheta_p = SIN(theta_p*pi180) 
      B_ctheta_p = COS(theta_p*pi180)

      ! Note: for performance reasons B_phi is always treated 0 in trgField
      B_phi_e    = phi_e
      B_sphi_e   = SIN(phi_e*pi180) 
      B_cphi_e   = COS(phi_e*pi180)

      B_phi_p    = phi_p
      B_sphi_p   = SIN(phi_p*pi180) 
      B_cphi_p   = COS(phi_p*pi180)
CGAW      write(*,*) 'trginit',theta_e,theta_p
! GAW 99/11/22: Add zero field option
      IF (map.EQ.'0') THEN
        DO ir=1,nr			
          rr(ir) = 2.*float(ir-1)	
          zz(ir) = 2.*float(ir-1)
          DO iz=1,nz
            B_field_r(iz,ir) = 0.
            B_field_z(iz,ir) = 0.
	  ENDDO
	ENDDO
! GAW 99/11/22: End 
      ELSEIF (map .NE. ' ') THEN           !read in numerical field map
        OPEN (unit=1,file=map,status='old')
          DO ir=1,nr
            rr(ir) = 2.*float(ir-1)
            zz(ir) = 2.*float(ir-1)
            DO iz=1,nz
              READ (1,*)xx,xx,B_field_z(iz,ir),B_field_r(iz,ir),xx,xx,xx
	      ! rescale field to desired value
	      B_field_z(iz,ir) = B_field_z(iz,ir) * scale
	      B_field_r(iz,ir) = B_field_r(iz,ir) * scale
          ENDDO
        ENDDO
        CLOSE (unit=1)
      ELSE

! GAW 99/11/19: Must initialize rr and zz before going through loop since 
! do tests on them.

        DO ir=1,nr			! uniform 5T field over 26 cm in z
          rr(ir) = 2.*float(ir-1)	! and 16 cm in r
          zz(ir) = 2.*float(ir-1)
        ENDDO
        DO ir=1,nr			! uniform 5T field over 26 cm in z
          DO iz=1,nz
            B_field_r(iz,ir) = 0.
            IF (rr(ir) .LE. 16. .and. zz(iz) .LE. 26.) THEN
CGAW              B_field_z(iz,ir) = 0.0
              B_field_z(iz,ir) = 5.0
            ELSE
	      B_field_z(iz,ir) = 0.0
	    ENDIF
	  ENDDO
	ENDDO
      ENDIF
 
      RETURN
      END
      
       
      SUBROUTINE trgField (x_,B_,spect)
      IMPLICIT NONE
!      REAL*8 x_(3),B_(3)
      REAL*8 x_(6),B_(3)
* --  calculate actual field
*
*     Parameter:
*        x_   I : lab coordinates  
*        B_   O : B field in lab coordinates
*        spect I: id for spectrometer (-1=e-, +1=p)
*
*      Notes:
*      - 2-Dimensional Linear Interpolation:                               
*        Assumes uniform spacing of fieldmap in x,y        
*      - for performance reasons B_phi is always treated 0 
*
* GAW 99/12/06 modified to work with 2 spectrometers
       
      INTEGER    nz,nr 
      PARAMETER (nz = 51)
      PARAMETER (nr = 51)

      REAL*8    B_field_z(nz,nr),B_field_r(nz,nr),zz(nz),rr(nr)
      REAL*8    B_theta_e,B_stheta_e,B_ctheta_e,B_phi_e,B_sphi_e,B_cphi_e 
      REAL*8    B_theta_p,B_stheta_p,B_ctheta_p,B_phi_p,B_sphi_p,B_cphi_p 
       
      COMMON  /trgFieldStrength/ B_field_z,B_field_r,zz,rr
      COMMON  /trgFieldAngles_e/ B_theta_e,B_stheta_e,B_ctheta_e,
     >                           B_phi_e,  B_sphi_e,  B_cphi_e 
      COMMON  /trgFieldAngles_p/ B_theta_p,B_stheta_p,B_ctheta_p,
     >                           B_phi_p,  B_sphi_p,  B_cphi_p 

      REAL*8 B_tht, B_stht, B_ctht, B_ph, B_sph, B_cph

      INTEGER i,j,spect
      REAL*8    x(3),B(3),z,r,az,ar,a0,a1

	real*8 xx(3),x_sur(2),y_sur(2),z_sur(2)	!	OR - 4/04
	real*8 azim,az0,az_corr,horiz,az_corr2	!	OR - 7/04
	real*8 B_scale,B_corr			!	OR - 7/04	
	logical forwd	!	OR - 4/04 B offset forward only
	common/fwd/forwd	!	OR -4/04
	integer flag_az	!	OR - 7/04
	logical azcor
        save B_scale
	common /azimuth/ flag_az	!	OR - 7/04	
!	data flagaz /1/
c
c Survey system z=beam downstream, x=left of beam y= above beam
c	
!	data    x_sur /-.161d0,  .123d0/, 
!	1	y_sur / .147d0,  .108d0/, 
!	1	z_sur / .339d0, -.205d0/! Survey offsets cm, 1= perp
!!	1	z_sur / .197d0, -.205d0/! Survey offsets cm, 1= perp
	
	data    x_sur / .0d0,  .0d0/ 
        data    y_sur / .0d0,  .0d0/ 
        data    z_sur / .0d0,  .0d0/! Survey offsets cm, 1= perp

! set up angles for electron or proton spectrometer

!	if(flag_az.eq.1.and.forwd) then	!	OR - 7/04
	  horiz=atan(x_(5)/x_(6))
	  azim=atan(x_(4)/(x_(6)*cos(horiz+0.2295)))
!	  azim=x_(4)/x_(6)
!	  flag_az = 0
!	 end if
	
      if (spect.eq.-1) then
        B_tht    = B_theta_e
        B_stht   = B_stheta_e
        B_ctht   = B_ctheta_e
        B_ph     = B_phi_e
        B_sph    = B_sphi_e
        B_cph    = B_cphi_e
      else if (spect.eq.1) then
        B_tht    = B_theta_p
        B_stht   = B_stheta_p
        B_ctht   = B_ctheta_p
        B_ph     = B_phi_p
        B_sph    = B_sphi_p
        B_cph    = B_cphi_p
      endif


	
      ! rotate to coordinates with z' along field direction
!      write(*,*) x,xx
      
      x(1) =           x_(1)
      x(2) =  B_stht*x_(3) + B_ctht*x_(2)
      x(3) =  B_ctht*x_(3) - B_stht*x_(2)  
  

      ! compute zylinder coordinates

	z  = ABS  (x(3))
	r  = SQRT (x(1)**2 + x(2)**2)
		
        
      ! interpolate the field map 
      i = INT((z-zz(1))/(zz(2)-zz(1))) + 1                                              
      j = INT((r-rr(1))/(rr(2)-rr(1))) + 1                                              
      IF ((i+1 .GT. nz) .OR. (i .LT. 1) .OR. 
     >    (j+1 .GT. nr) .OR. (j .LT. 1)) THEN                
!	Missing initialization of field - inserted by OR 4/04
        B(1)=0.
        B(2)=0.
        B(3)=0.

        B_(1)=0.
        B_(2)=0.
        B_(3)=0.
      ELSE                                                                     
        ! calculate the Bz component 
        az = ((z-zz(i))/(zz(2)-zz(1))) 
        ar = ((r-rr(j))/(rr(2)-rr(1))) 
        a0=az*(B_field_z(i+1,j)  -B_field_z(i,j))  +B_field_z(i,j)                                           
        a1=az*(B_field_z(i+1,j+1)-B_field_z(i,j+1))+B_field_z(i,j+1)                                           
        B(3) = (ar*(a1-a0)+a0)           
        IF (r .gt. 0.) THEN
          ! calculate the Bx,By components 
          a0=az*(B_field_r(i+1,j)  -B_field_r(i,j))  +B_field_r(i,j)                                           
          a1=az*(B_field_r(i+1,j+1)-B_field_r(i,j+1))+B_field_r(i,j+1)                                           
          B(2) = (ar*(a1-a0)+a0)/r
          IF (x(3) .LT. 0.) B(2)= -B(2)
          B(1) = B(2)*x(1)
          B(2) = B(2)*x(2)       
c
c Check azimuth correction B=B_0+(az_az0[rad])*az_corr[T/rad]
c

c Uncomment !f for forward-only azim corr. 
c uncomment !! to "cancel" azim corr.

!f	if(forwd) then
!	az0 = 0.d0	!	OR - 7/04
!	az0 = -0.04d0	!	OR - 7/04 az-off
!f	az0 = -0.025d0	!	OR - 7/04
!	az_corr = -0.36d1
!f	az_corr = 0.26d1	! az-off
!	az_corr = 0.26d1/5.003d0 ! not enough
!	az_corr = 0.d1
!	az_corr2 = -0.1
!f	B(3) = B(3)+(azim-az0)*az_corr
!	1	+(azim-az0)**2*az_corr2		  
!	B(3) = B(3)*(1+(azim-az0)*az_corr)! not enough
!f	B(2) = B(2)+(azim-az0)*az_corr
!!	else
!	az0 = 0.d0	!	OR - 7/04
!	az0 = -0.04d0	!	OR - 7/04 az-off
!!	az0 = -0.025d0	!	OR - 7/04
!	az_corr = -0.36d1
!!	az_corr = 0.26d1	! az-off
!	az_corr = 0.26d1/5.003d0 ! not enough
!	az_corr = 0.d0
!	az_corr2 = -0.1
!!	B(3) = B(3)+(azim-az0)*az_corr
!	1	+(azim-az0)**2*az_corr2		  
!	B(3) = B(3)*(1+(azim-az0)*az_corr)! not enough
!!	B(2) = B(2)+(azim-az0)*az_corr
!f	end if
	           
c
c New azim corr
c
!	azcor = .true.

c	if(B_tht.lt.0) then	! B_tht = -103.15 deg = perp
c	azcor = .true.	! = -90 - 13.15 (theta_e)
c	else if(B_tht.gt.0) then ! B_tht = 166.85 deg = para
	azcor = .false.	    ! = 180 - 13.15
c	end if
	
!no fwd	if(azcor.and.forwd) then

	if(azcor) then
	az0 = -0.025d0	!	OR - 7/04
	az_corr = 0.26d1	! az-off
!	az_corr2 = -0.1
	B_corr = (azim-az0)*az_corr
	
	if(flag_az.eq.1.and.forwd) then
	B_scale = 5.003/(5.003+abs(B_corr))
!	B_scale = B(3)/(B(3)+B_corr)	! B(3) = B_max = 5.003 the 1st. time
	flag_az = 0
	else
	B_scale = 1.d0
	end if
	
	B(3) = B(3)+B_corr
	B(3) = B(3)*B_scale
!	1	+(azim-az0)**2*az_corr2	! quadratic
	B(2) = B(2)+B_corr
	B(2) = B(2)*B_scale
	end if
!no fwd	end if
	
          ! transform B field to lab. system
          B_(1) =          B(1)  
          B_(2) = - B_stht*B(3) + B_ctht*B(2)
          B_(3) =   B_ctht*B(3) + B_stht*B(2)  
        ELSE  
          B_(1) =   0.
          B_(2) = - B_stht*B(3)
          B_(3) =   B_ctht*B(3)
        ENDIF
      ENDIF	   
       
      RETURN
      END

*------------------------------------------------------------------------------
* solve the differential equation of the particle  
*
      SUBROUTINE trgDeriv(u,dudt,spect)
      IMPLICIT NONE
      REAL*8 u(9),dudt(9)
* --  calculate the derivatives du(i)/dt for the runke kutta routine         
*
*     Parameter:
*       u     I : actual coordinate vector
*                   u(1,2,3)    I : x, y, z
*                   u(4,5,6)    I : dx/dt, dy/dt, dz/dt 
*                   u(7,8,9)    I : integral Bxdx, Bydy, Bzdz   
*       dudt  O : derivative du/dt
*                   dudt(1,2,3) : dx/dt, dy/dt, dz/dt 
*                   dudt(4,5,6) : d^2xdt^2, d^2ydt^2, d^2zdt^2
*                   dudt(7,8,9) : B x v
*       spect I : -1 for e spectrometer, +1 for p spectrometer

      REAL*8   factor
      COMMON /trgConversionFactor/factor
      INTEGER spect
      REAL*8   B(3)

      CALL trgField (u,B,spect)

      ! These are just the velocities
      dudt(1) = u(4)
      dudt(2) = u(5)
      dudt(3) = u(6)

      ! This is just (v_vec X B_vec)  
      dudt(7) = u(5)*B(3) - u(6)*B(2)
      dudt(8) = u(6)*B(1) - u(4)*B(3) 
      dudt(9) = u(4)*B(2) - u(5)*B(1)  

      ! This is just (v_vec X B_vec) * factor
      dudt(4) = dudt(7)*factor
      dudt(5) = dudt(8)*factor
      dudt(6) = dudt(9)*factor

      RETURN
      END
                                                                             
      SUBROUTINE trgRK4(u0,u1,h,spect)
      IMPLICIT NONE
      REAL*8     u0(6),u1(6),h
* --  Fourth-order Runge-Kutta from Numerical Recipes book
*     for tracking through the target field 
*
*     Parameter:
*       u0  I  : input  coordinate vector
*       u1  O  : output coordinate vector
*                u(1,2,3) : x, y, z
*                u(4,5,6) : dx/dt, dy/dt, dz/dt 
*       h   I  : time step
*       spect I: -1 for e spectrometer, +1 for p spectrometer
  
      INTEGER i,spect
      REAL*8    ut(6),dudt(9),dut(9),dum(9),hh,h6

      hh=h*0.5
      h6=h/6.
 
      CALL trgDeriv(u0,dudt,spect)
      DO i=1,6
	ut(i) = u0(i) + hh*dudt(i)
      ENDDO

      CALL trgDeriv(ut,dut,spect)
      DO i=1,6
	ut(i) = u0(i) + hh*dut(i)
      ENDDO

      CALL trgDeriv(ut,dum,spect)
      DO i=1,6
	ut(i) = u0(i) +h*dum(i)
        dum(i)= dut(i)  +dum(i)
      ENDDO

      CALL trgDeriv(ut,dut,spect)
      DO i=1,6
        u1(i)=u0(i)+h6*(dudt(i)+dut(i)+2.*dum(i))
      ENDDO

      RETURN       
      END
 
 
      SUBROUTINE trgRK4Bdl(u0,u1,h,spect)
      IMPLICIT NONE
      REAL*8     u0(9),u1(9),h
* --  Fourth-order Runge-Kutta from Numerical Recipes book
*     for tracking through the target field (incl. B/dl calculation)
*
*     Parameter:
*      u0  I  : input  coordinate vector
*      u1  O  : output coordinate vector
*                 u(1,2,3) : x, y, z
*                 u(4,5,6) : dx/dt, dy/dt, dz/dt 
*                 u(7,8,9) : integral Bxdx, Bydy, Bzdz   
*      h   I  : time step
*      spect I: -1 for e spectrometer, +1 for p spectrometer

      INTEGER i,spect
      REAL*8    ut(9),dudt(9),dut(9),dum(9),hh,h6

      hh=h*0.5
      h6=h/6.
 
      CALL trgDeriv(u0,dudt,spect)
      DO i=1,9
	ut(i) = u0(i) + hh*dudt(i)
      ENDDO

      CALL trgDeriv(ut,dut,spect)
      DO i=1,9
	ut(i) = u0(i) + hh*dut(i)
      ENDDO

      CALL trgDeriv(ut,dum,spect)
      DO i=1,9
	ut(i) = u0(i) +h*dum(i)
        dum(i)= dut(i)  +dum(i)
      ENDDO

      CALL trgDeriv(ut,dut,spect)
      DO i=1,9
        u1(i)=u0(i)+h6*(dudt(i)+dut(i)+2.*dum(i))
      ENDDO

      RETURN       
      END

C------------------------------------------------------------------------------
!
! Tracking of charged particles through the target field.
!
! Author: Glen Warren, December 1999
!
! Much of the code is taken from Markus Muehlbauer's work on the Hall C replay
! engine.
!
C------------------------------------------------------------------------------

!      subroutine track_from_tgt(x,y,z,dx,dy,mom,mass,spect,ok)
      subroutine track_from_tgt(x,y,z,dx,dy,mom,mass,spect,ok,bdl)

C Given vertex coordinates, momentum and mass, tracks particle through a
C field to field-free region 100 cm from target.  It is assumed that the 
C code that calls this routine will reconstruct the track to z=0.
C
C x,y,z,dx,dy coordinates follow COSY a la Hall C:
C   z = into spectrometer
C   x = down (direction of increasing momentum)
C   y = z cross x.
C   dx = dx/dz 
C   dy = dy/dz
C
C coordinates for tracking are:
C   vT(1,2,3) are the position in X,Y,Z [cm]
C   vT(4,5,6) are the velocity in the X,Y,Z direction [cm/ns].


      implicit none


      real*8 x,y,z,dx,dy      ! in: initial coords.  out: coords of image track
      real*8 mom              ! momentum (MeV). (mom<0 for e-, mom>0 for p,d)
      real*8 mass             ! mass of particle (MeV)
      integer spect
      logical ok
 
      real*8 cc               ! speed of light in cm/ns
      parameter (cc = 29.9792458)
      real*8 vel              ! velocity of particle [cm/ns]
      real*8 eng              ! energy of particle
!      real*8 vT(6)
      real*8 vT(9)	! OR - 4/04
	real bdl	!	OR - 4/04
	      
	logical forwd	! OR - 4/04
	common/fwd/forwd	!	OR - 4/04
	integer flag_az	!	OR - 7/04
	common /azimuth/flag_az	!	OR 7-04

	forwd = .false.	!	OR - 4/04
	flag_az = 0		!	OR - 7/04

c      write(*,*) 'from target',spect
c      write(*,*) mom,mass
c      call print_coord2('init track, beam: ',x,y,z,dx,dy)

      vel = abs(mom)/sqrt(mom**2+mass**2)*cc
      eng = sign(1.d00,mom)*sqrt(mom**2+mass**2)
c
c
      vT(1) = x 
      vT(2) = y
      vT(3) = z 

      vT(6) = vel/sqrt(1+dx**2+dy**2)
      vT(4) = dx*vT(6)
      vT(5) = dy*vT(6)

! for debugging, run track first to z=0.
      ok = .true.
      call trgTrackToPlane(vT,eng,1.d00,0.d00,0.d00,1.d00,0.d00,ok,spect)
c      write(*,*) ' debug call to trgtracktoplane ' ,ok,spect
	    
c      call print_coord3('init track, z=0:',vt)

! track through magnetic field to z=100 cm plane

      ok = .true.
      call trgTrackToPlane(vT,eng,1.d00,0.d00,0.d00,1.d00,-100.d00,ok,spect)
c     write(*,*) ' after z=-100. call',ok,spect
c      call print_coord3('init track, z=100:',vt)


! translate back into SIMC variables

      x = vT(1)
      y = vT(2)
      z = vT(3)

      dx = vT(4)/vT(6)
      dy = vT(5)/vt(6)
 
      return
      end
     

C------------------------------------------------------------------------------

!      subroutine track_to_tgt(delta,y,dx,dy,frx,fry,mom,mass,ctheta,
!     >                        stheta,spect,ok,xfp,xpfp,yfp,ypfp)
!      subroutine track_to_tgt(delta,y,dx,dy,frx,fry,mom,mass,ctheta,
!     >                        stheta,spect,ok,xfp,xpfp,yfp,ypfp,xtgt)	! OR 4/04
      subroutine track_to_tgt(delta,y,dx,dy,frx,fry,mom,mass,ctheta,
     >                   stheta,spect,ok,xfp,xpfp,yfp,ypfp,xtgt,bdl)	! OR 4/04

      implicit none

       real*8 delta,y,dx,dy      ! in: first guess reconstructed coords.
                                ! out: final reconstructed coords.
      real*8 frx                ! raster horizontal position (points right)
      real*8 fry                ! raster vertical position (points up)
      real*8 mom              ! momentum (MeV). (mom<0 for e-, mom>0 for p,d)
      real*8 mass             ! mass of particle (MeV)
      real*8 ctheta,stheta        ! cosine and sine of central spectrometer angle
      real*8 delta_y,delta_z
      real*8 xfp,yfp,xpfp,ypfp
      integer spect
      logical ok

!      real*8  vT(6),vTx(6)
      real*8  vT(9),vTx(9)	!	OR - 4/04
      real*8 xx,delx
      real*8 xxd
      integer*2 i,n
      real*8 vel,cc,eng,mom_0
      
	real*8 xtgt	!	OR 4/04
	real*8 bdl	!	OR - 4/04
	real*8 vtsave(6)
	integer ii
		
	logical forwd	! OR - 4/04
	common/fwd/forwd	!	OR - 4/04
	integer flag_az	!	OR - 7/04
	common /azimuth/flag_az	!	OR 7-04
	
      parameter (cc=29.9792458d00)

	forwd = .false.	!	OR - 4/04
!	flag_az = 1		!	OR - 7/04
	
! do reconstruction considering target field.  Taken from gen_track.f from 
! Markus Muehlbauer
!
	
	bdl = 0.0	!	OR - 4/04
!	bdl = -10.0	!	OR - 4/04

c      write(*,*) 'to target',spect
c      call print_coord1('after first mc_hms_recon',y,delta,dx,dy,fry,0.)

c
c initialize xtgt = x_tar - OR 4/04
c
	xtgt = 0.d0
!
! copy vertical offset into another variable

      xx  = -fry

! use first call to mc_hms_recon as a first guess. Next trace back 100 cm 
! to enter field free region and calculate vector for field tracking program.

      vel = abs(mom)/sqrt(mom**2+mass**2)*cc
      eng = sign(1.d00,mom)*sqrt(mom**2+mass**2)
      mom_0 = mom/(1.d0+delta/100.d0)

c      write(*,*) 'vel,eng,mom_0 = ',vel,eng,mom_0,y,dx,dy
      vT(1) = -fry    + 100.d00*dx
      vT(2) = y + 100.d00*dy
      vT(3) = 100.d00
      vT(6) = vel/SQRT(1+dy**2+dx**2)
      vT(4) = dx*vT(6)
      vT(5) = dy*vT(6) 

          do ii=1,6
           vtsave(ii)=vt(ii)
          enddo

c      call print_coord3('first track at z=100',vT)
      
! and track into the magnetic field to the beam plane (perp. to y)
c       write(*,*) ' Before 1st call trgtracktoplane ',vt
      ok = .true.
      CALL trgTrackToPlane (vT,eng,1.d00,0.d00,-ctheta,stheta,-frx,ok,spect)

!	write(*,*) ' Bdl - 1',vT(7),vT(8),vT(9),ok	!	OR - 4/04
      
c       write(*,*) ' 1st call trgtracktoplane ',-ctheta,stheta,frx,ok,vt
c      call print_coord3( 'first track on beam',vT)

      n  = 0
      delx = 1.
      DO WHILE ((delx .GT. .05) .AND. (n .LT. 10) .AND. ok)
        delx = abs(-fry-vT(1))
c	 write(*,*) '----------------'
c	 write(*,*) 'do while: ',n,delx

        ! track to the z=0 plane to find a correction for the x-offset   

        vTx(1) = -fry 
        DO i=2,6
          vTx(i) = vT(i)
        ENDDO
    
c        call print_coord3( 'vT,  beam',vT)
c        call print_coord3( 'vTx, beam',vTx)
        CALL trgTrackToPlane (vT, eng,1.d00,0.d00,0.d00,1.d00,0.d00,ok,spect)

!	write(*,*) ' Bdl - 2',vT(7),vT(8),vT(9),ok	!	OR - 4/04

        CALL trgTrackToPlane (vTx,eng,1.d00,0.d00,0.d00,1.d00,0.d00,ok,spect)

!	write(*,*) ' Bdl - 3',vTx(7),vTx(8),vTx(9),ok	!	OR - 4/04

c        call print_coord3( 'vT,   z=0',vT)
c        call print_coord3( 'vTx,  z=0',vTx)

        xx = xx+min(1.,max(-1.,(vTx(1)-vT(1))))
        xxd = xx

        ! now find a better approximation 

c        call print_coord1('before mc_hms_recon',y,delta,dx,dy,-xxd,0.)

	   call  simc_hms_recon (delta,dy,dx,y
     >                             ,xxd,xfp,xpfp,yfp,ypfp)

        mom = mom_0*(1.d0+delta/100.d0)
        vel = abs(mom)/sqrt(mom**2+mass**2)*cc
        eng = sign(1.d00,mom)*sqrt(mom**2+mass**2)
        
c        call print_coord1('after mc_hms_recon',y,delta,dx,dy,-xxd,0.)

        ! drift to a field free region and calculate the velocities

        vT(1) = xx + 100.d00*dx
        vT(2) = y  + 100.d00*dy
        vT(3) = 100.d00
        vT(6) = vel/SQRT(1+dy**2+dx**2)
        vT(4) = dx*vT(6)
        vT(5) = dy*vT(6) 
     
        ! and track into the magnetic field to the beam plane (perp. to y)

c        call print_coord3( 'before last track',vT)
c
c 10/20/2003 change frx to -frx which gives better resolution.
c
        CALL trgTrackToPlane (vT,eng,1.d00,0.d00,-ctheta,stheta,-frx,ok,spect)

        bdl = sqrt(vT(7)**2+vT(8)**2+vT(9)**2)	!	OR - 4/04

!	write(*,*) ' Bdl - 4',vT(7),vT(8),vT(9),ok,bdl	!	OR - 4/04

c        call print_coord3( 'after last track:',vT)
        n = n+1
      ENDDO

      IF (delx .GT. .2) ok = .FALSE.

c      if (.not. ok) write(*,*) ' failed',delx,fry,n,delta,dy,dx,y
c     >                             ,xxd,xfp,xpfp,yfp,ypfp           
      ! calculate the result in HMS coordinates

      dy = vT(5)/vT(6)
      dx = vT(4)/vT(6)
      y  = vT(2)
	xtgt = vT(1)	! x_tar - OR 4/04   
!x      write(*,*) 'd_xyz_tar vs bdl',vtsave(5)-vT(5),vtsave(4)-vT(4),
!x	1	vtsave(6)-vT(6),bdl
!x	write(*,*) 'xyz_tar vs bdl',vtsave(4),vt(4),vtsave(4)-vt(4),bdl
	
      return
      end

! routines to print coordinates given different input - GAW

      subroutine print_coord1(txt,y,delta,dxdz,dydz,x,z)
      implicit none
      character*(*) txt
      real*8 y,delta,dxdz,dydz,x,z
      real*8 vT(6)

      vt(1) = -x
      vt(2) = y
      vt(3) = z
      vt(6) = 30/sqrt(1.+dxdz**2+dydz**2)
      vt(4) = dxdz
      vt(5) = dydz
      
c      if (debug(6)) write(*,100) txt,vt(1),vt(2),vt(3),vt(4),
c     >            vt(5),sqrt(vt(4)**2+vt(5)**2+vt(6)**2)
      write(*,100) txt,vt(1),vt(2),vt(3),vt(4),
     >            vt(5),sqrt(vt(4)**2+vt(5)**2+vt(6)**2)

 100  format(a20,6f10.4)
      return
      end

      subroutine print_coord2(txt,x,y,z,dxdz,dydz)
      implicit none
      character*(*) txt
      real*8 y,dxdz,dydz,x,z
      real*8 vT(6)

      vt(1) = x
      vt(2) = y
      vt(3) = z
      vt(6) = 30/sqrt(1.+dxdz**2+dydz**2)
      vt(4) = dxdz
      vt(5) = dydz
      
c      if (debug(6)) write(*,100) txt,vt(1),vt(2),vt(3),vt(4),
c     >       vt(5),sqrt(vt(4)**2+vt(5)**2+vt(6)**2)

 100  format(a20,6f10.4)
      return
      end

      subroutine print_coord3(txt,vt)
      implicit none
      character*(*) txt
      real*8 vT(6)

c      if (debug(6)) write(*,100) txt,vt(1),vt(2),vt(3),vt(4)/vt(6),
c     >       vt(5)/vt(6),sqrt(vt(4)**2+vt(5)**2+vt(6)**2)

      write(*,100) txt,vt(1),vt(2),vt(3),vt(4)/vt(6),
     >       vt(5)/vt(6),sqrt(vt(4)**2+vt(5)**2+vt(6)**2)

 100  format(a20,6f10.4)
      return
      end
