!----------------------------------------------------------------------------------------
!
! Copyright (C) 2021 ENVIRON (www.quantum-environ.org)
!
!----------------------------------------------------------------------------------------
!
!     This file is part of Environ version 2.0
!
!     Environ 2.0 is free software: you can redistribute it and/or modify
!     it under the terms of the GNU General Public License as published by
!     the Free Software Foundation, either version 2 of the License, or
!     (at your option) any later version.
!
!     Environ 2.0 is distributed in the hope that it will be useful,
!     but WITHOUT ANY WARRANTY; without even the implied warranty of
!     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!     GNU General Public License for more detail, either the file
!     `License' in the root directory of the present distribution, or
!     online at <http://www.gnu.org/licenses/>.
!
!----------------------------------------------------------------------------------------
!
! Authors: Oliviero Andreussi (Department of Physics, UNT)
!          Francesco Nattino  (THEOS and NCCR-MARVEL, EPFL)
!          Ismaila Dabo       (DMSE, Penn State)
!          Nicola Marzari     (THEOS and NCCR-MARVEL, EPFL)
!          Edan Bainglass     (Department of Physics, UNT)
!
!----------------------------------------------------------------------------------------
!>
!!
!----------------------------------------------------------------------------------------
MODULE class_environ
    !------------------------------------------------------------------------------------
    !
    USE env_base_io
    !
    USE environ_param, ONLY: DP, BOHR_RADIUS_SI, RYDBERG_SI
    !
    USE env_base_input
    USE env_setup
    !
    USE class_cell
    USE class_density
    USE class_gradient
    USE class_mapping
    !
    USE class_boundary
    USE class_charges
    USE class_dielectric
    USE class_electrolyte
    USE class_electrons
    USE class_externals
    USE class_ions
    USE class_semiconductor
    USE class_system
    !
    USE env_write_cube
    !
    !------------------------------------------------------------------------------------
    !
    IMPLICIT NONE
    !
    PRIVATE
    !
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    TYPE, PUBLIC :: environ_obj
        !--------------------------------------------------------------------------------
        !
        TYPE(environ_setup), POINTER :: setup => NULL()
        !
        !--------------------------------------------------------------------------------
        ! Mapped quantities
        !
        TYPE(environ_ions) :: system_ions, environment_ions
        TYPE(environ_system) :: system_system, environment_system
        TYPE(environ_electrons) :: system_electrons, environment_electrons
        TYPE(environ_charges) :: system_charges, environment_charges
        !
        !--------------------------------------------------------------------------------
        ! Details of the continuum interface
        !
        TYPE(environ_boundary) :: solvent
        !
        !--------------------------------------------------------------------------------
        ! Response properties
        !
        TYPE(environ_electrons) :: system_response_electrons, &
                                   environment_response_electrons
        !
        TYPE(environ_charges) :: system_response_charges, &
                                 environment_response_charges
        !
        !--------------------------------------------------------------------------------
        ! Physical objects
        !
        TYPE(environ_externals) :: externals
        TYPE(environ_dielectric) :: static, optical
        TYPE(environ_electrolyte) :: electrolyte
        TYPE(environ_semiconductor) :: semiconductor
        !
        !--------------------------------------------------------------------------------
        ! Computed physical variables
        !
        TYPE(environ_density) :: &
            vzero, velectrostatic, vreference, dvtot, vconfine, vsoftcavity
        !
        REAL(DP) :: evolume = 0.0_DP
        REAL(DP) :: esurface = 0.0_DP
        REAL(DP) :: econfine = 0.0_DP
        REAL(DP) :: deenviron = 0.0_DP
        REAL(DP) :: eelectrolyte = 0.0_DP
        REAL(DP) :: eelectrostatic = 0.0_DP
        !
        !--------------------------------------------------------------------------------
    CONTAINS
        !--------------------------------------------------------------------------------
        !
        PROCEDURE, PRIVATE :: create => create_environ_base
        PROCEDURE :: init => init_environ_base
        !
        PROCEDURE, PRIVATE :: init_physical => environ_init_physical
        PROCEDURE, PRIVATE :: init_potential => environ_init_potential
        !
        PROCEDURE :: update_electrons => environ_update_electrons
        PROCEDURE :: update_ions => environ_update_ions
        PROCEDURE :: update_potential => environ_update_potential
        PROCEDURE :: update_response => environ_update_response
        PROCEDURE :: update_cell_dependent_quantities
        !
        PROCEDURE :: force => calc_fenviron
        PROCEDURE :: energy => calc_eenviron
        PROCEDURE :: denergy => calc_deenviron
        PROCEDURE :: potential => calc_venviron
        PROCEDURE :: dpotential => calc_dvenviron
        !
        !--------------------------------------------------------------------------------
    END TYPE environ_obj
    !------------------------------------------------------------------------------------
    !
    !------------------------------------------------------------------------------------
CONTAINS
    !------------------------------------------------------------------------------------
    !------------------------------------------------------------------------------------
    !
    !                                   ADMIN METHODS
    !
    !------------------------------------------------------------------------------------
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE create_environ_base(this)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        CLASS(environ_obj), INTENT(INOUT) :: this
        !
        CHARACTER(LEN=80) :: sub_name = 'create_environ_base'
        !
        !--------------------------------------------------------------------------------
        !
        IF (ASSOCIATED(this%setup)) &
            CALL env_errore(sub_name, 'Trying to create an existing object', 1)
        !
        !--------------------------------------------------------------------------------
        !
        NULLIFY (this%setup)
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE create_environ_base
    !------------------------------------------------------------------------------------
    !>
    !! Subroutine to initialize fundamental quantities needed by the
    !! environ modules. This subroutine is called by init_run.f90, thus
    !! only once per pw.x execution.
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE init_environ_base(this, setup, nelec, nat, ntyp, atom_label, ityp, zv)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_setup), TARGET, INTENT(IN) :: setup
        !
        INTEGER, INTENT(IN) :: nat, ntyp
        INTEGER, INTENT(IN) :: nelec, ityp(nat)
        REAL(DP), INTENT(IN) :: zv(ntyp)
        CHARACTER(LEN=3), INTENT(IN) :: atom_label(:)
        !
        CLASS(environ_obj), TARGET, INTENT(INOUT) :: this
        !
        !--------------------------------------------------------------------------------
        !
        this%setup => setup
        !
        CALL this%init_potential()
        !
        CALL this%init_physical(nelec, nat, ntyp, atom_label, ityp, zv)
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE init_environ_base
    !------------------------------------------------------------------------------------
    !>
    !! Save local potential that will be overwritten by environ
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE environ_update_potential(this, nnr, vltot)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        INTEGER, INTENT(IN) :: nnr
        REAL(DP), INTENT(IN) :: vltot(nnr)
        !
        CLASS(environ_obj), INTENT(INOUT) :: this
        !
        CHARACTER(LEN=80) :: sub_name = 'environ_update_potential'
        !
        !--------------------------------------------------------------------------------
        !
        this%vzero%lupdate = .TRUE.
        !
        IF (.NOT. ASSOCIATED(this%vzero%cell)) RETURN
        !
        IF (this%vzero%cell%nnr /= nnr) &
            CALL env_errore(sub_name, 'Inconsistent size in input potential', 1)
        !
        this%vzero%of_r = vltot
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE environ_update_potential
    !------------------------------------------------------------------------------------
    !>
    !! Update fixed quantities defined inside the cell
    !! NOTE: updating depends on cell%lupdate
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE update_cell_dependent_quantities(this)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        CLASS(environ_obj), INTENT(INOUT) :: this
        !
        CHARACTER(LEN=80) :: sub_name = 'update_cell_dependent_quantities'
        !
        !--------------------------------------------------------------------------------
        !
        IF (this%setup%lstatic) CALL this%static%update()
        !
        IF (this%setup%loptical) CALL this%optical%update()
        !
        IF (this%setup%lelectrolyte) CALL this%electrolyte%update()
        !
        IF (this%setup%lexternals) CALL this%externals%update()
        !
        IF (this%setup%lsemiconductor) CALL this%semiconductor%update()
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE update_cell_dependent_quantities
    !------------------------------------------------------------------------------------
    !>
    !! Initialize the ions-related quantities to be used in the Environ
    !! modules. This initialization is called by electrons.f90, thus it
    !! is performed at every step of electronic optimization. It may not
    !! be the most efficient choice, but it is a safe choice.
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE environ_update_ions(this, nat, tau)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        INTEGER, INTENT(IN) :: nat
        REAL(DP), INTENT(IN) :: tau(3, nat)
        !
        CLASS(environ_obj), INTENT(INOUT) :: this
        !
        !--------------------------------------------------------------------------------
        !
        this%system_ions%lupdate = .TRUE.
        this%environment_ions%lupdate = .TRUE.
        !
        !--------------------------------------------------------------------------------
        ! Update system ions parameters
        !
        CALL this%system_ions%update(nat, tau)
        !
        CALL this%system_ions%printout()
        !
        !--------------------------------------------------------------------------------
        ! Update system system parameters
        !
        this%system_system%lupdate = .TRUE.
        !
        CALL this%system_system%update()
        !
        CALL this%system_system%printout()
        !
        !--------------------------------------------------------------------------------
        !
        CALL this%setup%update_mapping(this%system_system%pos)
        ! update mapping with correct shift of environment cell
        !
        !--------------------------------------------------------------------------------
        ! Update environment ions parameters
        !
        CALL this%environment_ions%update(nat, tau)
        !
        CALL this%environment_ions%printout()
        !
        !--------------------------------------------------------------------------------
        ! Update environment system parameters
        !
        this%environment_system%lupdate = .TRUE.
        !
        CALL this%environment_system%update()
        !
        CALL this%environment_system%printout()
        !
        !--------------------------------------------------------------------------------
        ! Set soft-sphere parameters
        !
        IF (this%setup%lsolvent) CALL this%solvent%set_soft_spheres()
        !
        IF (this%setup%lelectrolyte) CALL this%electrolyte%boundary%set_soft_spheres()
        !
        !--------------------------------------------------------------------------------
        ! Update cores ! #TODO not OOP compliant - rethink!
        !
        IF (this%setup%l1da) &
            CALL this%setup%core_1da_elect%update_origin(this%environment_system%pos)
        !
        !--------------------------------------------------------------------------------
        ! Update rigid environ properties, defined on ions
        !
        IF (this%setup%lrigidcavity) THEN
            !
            IF (this%setup%lsolvent) THEN
                !
                CALL this%solvent%update()
                !
                IF (this%solvent%update_status == 2) CALL this%solvent%printout()
                !
                !------------------------------------------------------------------------
                ! Update quantities that depend on the solvent boundary
                !
                IF (this%setup%lstatic) THEN
                    !
                    CALL this%static%update()
                    !
                    IF (.NOT. this%static%lupdate) CALL this%static%printout()
                    !
                END IF
                !
                IF (this%setup%loptical) THEN
                    !
                    CALL this%optical%update()
                    !
                    IF (.NOT. this%optical%lupdate) CALL this%optical%printout()
                    !
                END IF
                !
            END IF
            !
            IF (this%setup%lelectrolyte) THEN
                !
                CALL this%electrolyte%boundary%update()
                !
                IF (this%electrolyte%boundary%update_status == 2) &
                    CALL this%electrolyte%boundary%printout()
                !
                CALL this%electrolyte%update()
                !
                IF (.NOT. this%electrolyte%lupdate) CALL this%electrolyte%printout()
                !
            END IF
            !
        END IF
        !
        !--------------------------------------------------------------------------------
        ! External charges rely on the environment cell, which is defined
        ! with respect to the system origin
        !
        IF (this%setup%lexternals) CALL this%externals%update()
        !
        IF (this%setup%lelectrostatic .OR. this%setup%lconfine) THEN
            !
            CALL this%system_charges%update()
            !
            CALL this%environment_charges%update()
            !
        END IF
        !
        this%system_system%lupdate = .FALSE.
        this%system_ions%lupdate = .FALSE.
        this%environment_system%lupdate = .FALSE.
        this%environment_ions%lupdate = .FALSE.
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE environ_update_ions
    !------------------------------------------------------------------------------------
    !>
    !! Initialize the electrons-related quantities to be used in the Environ
    !! modules. This initialization is called by electrons.f90, thus it
    !! is performed at every step of electronic optimization.
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE environ_update_electrons(this, nnr, rho, nelec)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        INTEGER, INTENT(IN) :: nnr
        REAL(DP), INTENT(IN) :: rho(nnr)
        REAL(DP), INTENT(IN), OPTIONAL :: nelec
        !
        CLASS(environ_obj), TARGET, INTENT(INOUT) :: this
        !
        REAL(DP), ALLOCATABLE :: aux(:)
        !
        TYPE(environ_cell), POINTER :: environment_cell
        !
        !--------------------------------------------------------------------------------
        !
        environment_cell => this%setup%environment_cell
        !
        !--------------------------------------------------------------------------------
        !
        this%system_electrons%lupdate = .TRUE.
        this%environment_electrons%lupdate = .TRUE.
        !
        !--------------------------------------------------------------------------------
        ! Update electrons parameters
        !
        CALL this%system_electrons%update(nnr, rho, nelec)
        !
        this%system_electrons%density%label = 'small_electrons'
        !
        ! CALL this%system_electrons%density%write_cube() ! DEBUGGING
        !
        IF (this%setup%ldoublecell) THEN
            ALLOCATE (aux(environment_cell%nnr))
            !
            CALL this%setup%mapping%to_large(nnr, environment_cell%nnr, rho, aux)
            !
            CALL this%environment_electrons%update(environment_cell%nnr, aux, nelec)
            !
        ELSE
            CALL this%environment_electrons%update(nnr, rho, nelec)
        END IF
        !
        this%environment_electrons%density%label = 'large_electrons'
        !
        ! CALL this%environment_electrons%density%write_cube() ! DEBUGGING
        !
        ! STOP ! DEBUGGING
        !
        CALL this%system_electrons%printout()
        !
        CALL this%environment_electrons%printout()
        !
        IF (this%setup%lelectrostatic .OR. this%setup%lconfine) THEN
            !
            CALL this%system_charges%update()
            !
            CALL this%environment_charges%update()
            !
        END IF
        !
        !--------------------------------------------------------------------------------
        ! Update soft environ properties, defined on electrons
        !
        IF (this%setup%lsoftcavity) THEN
            !
            IF (this%setup%lsoftsolvent) THEN
                !
                CALL this%solvent%update()
                !
                IF (this%solvent%update_status == 2) CALL this%solvent%printout()
                !
                !------------------------------------------------------------------------
                ! Update quantities that depend on the solvent boundary
                !
                IF (this%setup%lstatic) THEN
                    !
                    CALL this%static%update()
                    !
                    IF (.NOT. this%static%lupdate) CALL this%static%printout()
                    !
                END IF
                !
                IF (this%setup%loptical) THEN
                    !
                    CALL this%optical%update()
                    !
                    IF (.NOT. this%optical%lupdate) CALL this%optical%printout()
                    !
                END IF
                !
            END IF
            !
            IF (this%setup%lsoftelectrolyte) THEN
                !
                CALL this%electrolyte%boundary%update()
                !
                IF (this%electrolyte%boundary%update_status == 2) &
                    CALL this%electrolyte%boundary%printout()
                !
                CALL this%electrolyte%update()
                !
                IF (.NOT. this%electrolyte%lupdate) CALL this%electrolyte%printout()
                !
            END IF
            !
        END IF
        !
        this%system_electrons%lupdate = .FALSE.
        this%environment_electrons%lupdate = .FALSE.
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE environ_update_electrons
    !------------------------------------------------------------------------------------
    !>
    !! Initialize the response charges to be used in the TDDFPT + Environ
    !! modules. This initialization is called by plugin_tddfpt_potential.f90
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE environ_update_response(this, nnr, drho)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        INTEGER, INTENT(IN) :: nnr
        REAL(DP), INTENT(IN) :: drho(nnr)
        !
        CLASS(environ_obj), TARGET, INTENT(INOUT) :: this
        !
        REAL(DP), ALLOCATABLE :: aux(:)
        !
        TYPE(environ_cell), POINTER :: environment_cell
        !
        !--------------------------------------------------------------------------------
        !
        environment_cell => this%setup%environment_cell
        !
        !--------------------------------------------------------------------------------
        !
        this%system_response_electrons%lupdate = .TRUE.
        this%environment_response_electrons%lupdate = .TRUE.
        !
        !--------------------------------------------------------------------------------
        ! Update response charges in system cell
        !
        CALL this%system_response_electrons%update(nnr, drho, 0.D0)
        !
        CALL this%system_response_charges%update()
        !
        !--------------------------------------------------------------------------------
        ! Update response charges in environment cell
        !
        IF (this%setup%ldoublecell) THEN
            !
            ALLOCATE (aux(environment_cell%nnr))
            !
            CALL this%setup%mapping%to_large(nnr, environment_cell%nnr, drho, aux)
            !
            CALL this%environment_response_electrons%update(environment_cell%nnr, &
                                                            aux, 0.D0)
            !
        ELSE
            CALL this%environment_response_electrons%update(nnr, drho, 0.D0)
        END IF
        !
        CALL this%environment_response_charges%update()
        !
        this%system_response_electrons%lupdate = .FALSE.
        this%environment_response_electrons%lupdate = .FALSE.
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE environ_update_response
    !------------------------------------------------------------------------------------
    !------------------------------------------------------------------------------------
    !
    !                                  GENERAL METHODS
    !
    !------------------------------------------------------------------------------------
    !------------------------------------------------------------------------------------
    !>
    !! Calculates the Environ contribution to the local potential. All
    !! the Environ modules need to be called here. The potentials are
    !! all computed on the dense real-space grid and added to vtot.
    !
    !------------------------------------------------------------------------------------
    SUBROUTINE calc_venviron(this, update, local_verbose)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        LOGICAL, INTENT(IN) :: update
        INTEGER, INTENT(IN), OPTIONAL :: local_verbose
        !
        CLASS(environ_obj), TARGET, INTENT(INOUT) :: this
        !
        TYPE(environ_density) :: aux
        TYPE(environ_density) :: de_dboundary
        !
        TYPE(environ_mapping), POINTER :: mapping
        !
        CHARACTER(LEN=80) :: sub_name = 'calc_venviron'
        !
        !--------------------------------------------------------------------------------
        !
        mapping => this%setup%mapping
        !
        !--------------------------------------------------------------------------------
        ! If not updating the potentials, add old potentials and exit
        !
        IF (.NOT. update) THEN
            !
            IF (PRESENT(local_verbose)) THEN
                !
                CALL write_cube(this%dvtot, this%system_ions, local_verbose)
                !
                IF (this%setup%lelectrostatic) THEN
                    !
                    CALL write_cube(this%vreference, this%system_ions, local_verbose)
                    !
                    CALL write_cube(this%velectrostatic, this%system_ions, local_verbose)
                    !
                    CALL this%system_charges%printout(local_verbose)
                    !
                END IF
                !
                IF (this%setup%lconfine) &
                    CALL write_cube(this%vconfine, this%system_ions, local_verbose)
                !
                IF (this%setup%lsoftcavity) &
                    CALL write_cube(this%vsoftcavity, this%system_ions, local_verbose)
                !
            END IF
            !
            RETURN
            !
        END IF
        !
        this%dvtot%of_r = 0.D0
        !
        CALL aux%init(this%setup%system_cell)
        !
        !--------------------------------------------------------------------------------
        ! If any form of electrostatic embedding is present, calculate its contribution
        !
        IF (this%setup%lelectrostatic) THEN
            !
            !----------------------------------------------------------------------------
            ! Electrostatics is also computed inside the calling program,
            ! need to remove the reference #TODO to-be-decided
            !
            CALL this%setup%reference%calc_v(this%system_charges, this%vreference)
            !
            CALL write_cube(this%vreference, this%system_ions)
            !
            CALL this%setup%outer%calc_v(this%environment_charges, this%velectrostatic)
            !
            ! IF (this%setup%lexternals) CALL this%environment_charges%update()
            ! #TODO keep for now until external tests are fully debugged
            !
            CALL write_cube(this%velectrostatic, this%system_ions)
            !
            CALL mapping%to_small(this%velectrostatic, aux)
            !
            this%dvtot%of_r = aux%of_r - this%vreference%of_r
            !
            CALL this%environment_charges%of_potential(this%velectrostatic)
            !
            CALL this%environment_charges%printout()
            !
        END IF
        !
        !--------------------------------------------------------------------------------
        ! #TODO add brief description of confine
        !
        IF (this%setup%lconfine) THEN
            !
            CALL this%solvent%vconfine(this%setup%confine, this%vconfine)
            !
            CALL write_cube(this%vconfine, this%system_ions)
            !
            CALL mapping%to_small(this%vconfine, aux)
            !
            this%dvtot%of_r = this%dvtot%of_r + aux%of_r
        END IF
        !
        !--------------------------------------------------------------------------------
        ! Compute the total potential depending on the boundary
        !
        IF (this%setup%lsoftcavity) THEN
            this%vsoftcavity%of_r = 0.D0
            !
            CALL de_dboundary%init(this%setup%environment_cell)
            !
            IF (this%setup%lsoftsolvent) THEN
                de_dboundary%of_r = 0.D0
                !
                ! if surface tension greater than zero, calculate cavity contribution
                IF (this%setup%lsurface) &
                    CALL this%solvent%desurface_dboundary(this%setup%surface_tension, &
                                                          de_dboundary)
                !
                ! if external pressure different from zero, calculate PV contribution
                IF (this%setup%lvolume) &
                    CALL this%solvent%devolume_dboundary(this%setup%pressure, &
                                                         de_dboundary)
                !
                ! if confinement potential not zero, calculate confine contribution
                IF (this%setup%lconfine) &
                    CALL this%solvent%deconfine_dboundary(this%setup%confine, &
                                                          this%environment_charges%electrons%density, &
                                                          de_dboundary)
                !
                ! if dielectric embedding, calculate dielectric contribution
                IF (this%setup%lstatic) &
                    CALL this%static%de_dboundary(this%velectrostatic, de_dboundary)
                !
                ! if solvent-aware interface correct the potential
                IF (this%solvent%solvent_aware) &
                    CALL this%solvent%sa_de_dboundary(de_dboundary)
                !
                IF (this%solvent%field_aware) THEN
                    CALL env_errore(sub_name, 'field-aware not yet implimented ', 1)
                ELSE
                    !
                    this%vsoftcavity%of_r = de_dboundary%of_r * this%solvent%dscaled%of_r
                    ! multiply by derivative of the boundary w.r.t electronic density
                    !
                END IF
                !
            END IF
            !
            IF (this%setup%lsoftelectrolyte) THEN
                de_dboundary%of_r = 0.D0
                !
                CALL this%electrolyte%de_dboundary(de_dboundary)
                ! if electrolyte is present add its non-electrostatic contribution
                !
                ! if solvent-aware interface correct the potential
                IF (this%electrolyte%boundary%solvent_aware) &
                    CALL this%electrolyte%boundary%sa_de_dboundary(de_dboundary)
                !
                IF (this%electrolyte%boundary%field_aware) THEN
                    CALL env_errore(sub_name, 'field-aware not yet implimented ', 1)
                ELSE
                    !
                    ! multiply for the derivative of the boundary w.r.t electronic density
                    this%vsoftcavity%of_r = &
                        this%vsoftcavity%of_r + &
                        de_dboundary%of_r * this%electrolyte%boundary%dscaled%of_r
                    !
                END IF
                !
            END IF
            !
            CALL write_cube(this%vsoftcavity, this%system_ions)
            !
            CALL mapping%to_small(this%vsoftcavity, aux)
            !
            this%dvtot%of_r = this%dvtot%of_r + aux%of_r
            !
            CALL de_dboundary%destroy()
            !
        END IF
        !
        CALL aux%destroy()
        !
        CALL write_cube(this%dvtot, this%system_ions, local_verbose)
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE calc_venviron
    !------------------------------------------------------------------------------------
    !>
    !! Calculates the Environ contribution to the energy. We must remove
    !! int v_environ * rhoelec that is automatically included in the
    !! energy computed as the sum of Kohn-Sham eigenvalues.
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE calc_eenviron(this, total_energy)
        !--------------------------------------------------------------------------------
        !
        ! USE embedding_confine, ONLY: calc_econfine #TODO to-be-decided
        !
        IMPLICIT NONE
        !
        CLASS(environ_obj), INTENT(INOUT) :: this
        REAL(DP), INTENT(INOUT) :: total_energy
        !
        REAL(DP) :: ereference
        !
        !--------------------------------------------------------------------------------
        !
        this%eelectrostatic = 0.D0
        this%esurface = 0.D0
        this%evolume = 0.D0
        this%econfine = 0.D0
        this%eelectrolyte = 0.D0
        !
        this%setup%niter = this%setup%niter + 1
        !
        !--------------------------------------------------------------------------------
        ! If electrostatic is on, compute electrostatic energy
        !
        IF (this%setup%lelectrostatic) THEN
            !
            CALL this%setup%reference%calc_e(this%system_charges, this%vreference, &
                                             ereference)
            !
            CALL this%setup%outer%calc_e(this%environment_charges, &
                                         this%velectrostatic, this%eelectrostatic)
            !
            this%eelectrostatic = this%eelectrostatic - ereference
        END IF
        !
        !--------------------------------------------------------------------------------
        !
        ! if surface tension not zero, compute cavitation energy
        IF (this%setup%lsurface) &
            CALL this%solvent%esurface(this%setup%surface_tension, this%esurface)
        !
        IF (this%setup%lvolume) CALL this%solvent%evolume(this%setup%pressure, this%evolume)
        ! if pressure not zero, compute PV energy
        !
        ! if confinement potential not zero compute confine energy
        IF (this%setup%lconfine) &
            this%econfine = this%environment_electrons%density%scalar_product(this%vconfine)
        !
        ! if electrolyte is present, calculate its non-electrostatic contribution
        IF (this%setup%lelectrolyte) CALL this%electrolyte%energy(this%eelectrolyte)
        !
        total_energy = total_energy + this%eelectrostatic + this%esurface + &
                       this%evolume + this%econfine + this%eelectrolyte
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE calc_eenviron
    !------------------------------------------------------------------------------------
    !>
    !! Calculates the Environ contribution to the forces. Due to
    !! Hellman-Feynman only a few of the Environ modules have an
    !! effect on the atomic forces.
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE calc_fenviron(this, nat, force_environ)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        INTEGER, INTENT(IN) :: nat
        !
        CLASS(environ_obj), TARGET, INTENT(INOUT) :: this
        REAL(DP), INTENT(INOUT) :: force_environ(3, nat)
        !
        INTEGER :: i
        TYPE(environ_density) :: de_dboundary
        TYPE(environ_gradient) :: partial
        !
        TYPE(environ_cell), POINTER :: environment_cell
        !
        REAL(DP), DIMENSION(3, nat) :: freference, felectrostatic
        !
        !--------------------------------------------------------------------------------
        !
        environment_cell => this%setup%environment_cell
        !
        !--------------------------------------------------------------------------------
        ! Compute the electrostatic embedding contribution to the interatomic forces.
        ! If using doublecell, take the difference of contributions from the full charge
        ! density computed in the environment cell (outer solver) and those from the
        ! charge density of ions/electrons computed in the system cell (reference solver)
        !
        force_environ = 0.D0
        freference = 0.D0
        !
        IF (this%setup%lelectrostatic) THEN
            !
            CALL this%setup%outer%calc_f(nat, this%environment_charges, felectrostatic, &
                                         this%setup%ldoublecell)
            !
            IF (this%setup%ldoublecell) THEN
                !
                CALL this%setup%reference%calc_f(nat, this%system_charges, freference, &
                                                 this%setup%ldoublecell)
                !
            END IF
            !
            force_environ = felectrostatic - freference
        END IF
        !
        !--------------------------------------------------------------------------------
        ! Compute the total forces depending on the boundary
        !
        IF (this%setup%lrigidcavity) THEN
            !
            CALL de_dboundary%init(environment_cell)
            !
            CALL partial%init(environment_cell)
            !
            IF (this%setup%lrigidsolvent) THEN
                !
                de_dboundary%of_r = 0.D0
                !
                ! if surface tension greater than zero, calculate cavity contribution
                IF (this%setup%lsurface) &
                    CALL this%solvent%desurface_dboundary(this%setup%surface_tension, &
                                                          de_dboundary)
                !
                ! if external pressure not zero, calculate PV contribution
                IF (this%setup%lvolume) &
                    CALL this%solvent%devolume_dboundary(this%setup%pressure, de_dboundary)
                !
                ! if confinement potential not zero, calculate confine contribution
                IF (this%setup%lconfine) &
                    CALL this%solvent%deconfine_dboundary(this%setup%confine, &
                                                          this%environment_charges%electrons%density, &
                                                          de_dboundary)
                !
                ! if dielectric embedding, calculate dielectric contribution
                IF (this%setup%lstatic) &
                    CALL this%static%de_dboundary(this%velectrostatic, de_dboundary)
                !
                ! if solvent-aware, correct the potential
                IF (this%solvent%solvent_aware) &
                    CALL this%solvent%sa_de_dboundary(de_dboundary)
                !
                !------------------------------------------------------------------------
                ! Multiply by derivative of the boundary w.r.t ionic positions
                !
                DO i = 1, nat
                    !
                    CALL this%solvent%dboundary_dions(i, partial)
                    !
                    force_environ(:, i) = force_environ(:, i) - &
                                          partial%scalar_product_density(de_dboundary)
                    !
                END DO
                !
            END IF
            !
            IF (this%setup%lrigidelectrolyte) THEN
                !
                de_dboundary%of_r = 0.D0
                !
                ! if electrolyte is present, add its non-electrostatic contribution
                CALL this%electrolyte%de_dboundary(de_dboundary)
                !
                ! if solvent-aware, correct the potential
                IF (this%electrolyte%boundary%solvent_aware) &
                    CALL this%electrolyte%boundary%sa_de_dboundary(de_dboundary)
                !
                !------------------------------------------------------------------------
                ! Multiply by derivative of the boundary w.r.t ionic positions
                !
                DO i = 1, nat
                    !
                    CALL this%electrolyte%boundary%dboundary_dions(i, partial)
                    !
                    force_environ(:, i) = force_environ(:, i) - &
                                          partial%scalar_product_density(de_dboundary)
                    !
                END DO
                !
            END IF
            !
            CALL partial%destroy()
            !
            CALL de_dboundary%destroy()
            !
        END IF
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE calc_fenviron
    !------------------------------------------------------------------------------------
    !>
    !! Calculates the Environ contribution to the response potential in TD calculations
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE calc_dvenviron(this, nnr, dv)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        INTEGER, INTENT(IN) :: nnr
        !
        CLASS(environ_obj), TARGET, INTENT(INOUT) :: this
        REAL(DP), INTENT(INOUT) :: dv(nnr)
        !
        TYPE(environ_density) :: aux
        TYPE(environ_density) :: dvreference
        TYPE(environ_density) :: dvelectrostatic
        TYPE(environ_density) :: dvsoftcavity
        TYPE(environ_density) :: dv_dboundary
        !
        TYPE(environ_cell), POINTER :: system_cell, environment_cell
        TYPE(environ_mapping), POINTER :: mapping
        !
        !--------------------------------------------------------------------------------
        !
        system_cell => this%setup%system_cell
        environment_cell => this%setup%environment_cell
        mapping => this%setup%mapping
        !
        !--------------------------------------------------------------------------------
        !
        CALL aux%init(system_cell)
        !
        !--------------------------------------------------------------------------------
        ! If any form of electrostatic embedding is present, calculate its contribution
        !
        IF (this%setup%lelectrostatic) THEN
            !
            !----------------------------------------------------------------------------
            ! Electrostatics is also computed inside the calling program,
            ! need to remove the reference
            !
            CALL dvreference%init(system_cell)
            !
            CALL this%setup%reference%calc_v(this%system_response_charges, dvreference)
            !
            CALL dvelectrostatic%init(environment_cell)
            !
            CALL this%setup%outer%calc_v(this%environment_response_charges, &
                                         dvelectrostatic)
            !
            CALL mapping%to_small(dvelectrostatic, aux)
            !
            dv(:) = dv(:) + aux%of_r(:) - dvreference%of_r(:)
            !
            CALL dvreference%destroy()
            !
        END IF
        !
        !--------------------------------------------------------------------------------
        ! Compute the response potential depending on the boundary
        !
        IF (this%setup%lsoftcavity) THEN
            !
            CALL dvsoftcavity%init(environment_cell)
            !
            CALL dv_dboundary%init(environment_cell)
            !
            IF (this%setup%lsoftsolvent) THEN
                dv_dboundary%of_r = 0.D0
                !
                ! if dielectric embedding, calcultes dielectric contribution
                IF (this%setup%loptical) &
                    CALL this%optical%dv_dboundary(this%velectrostatic, &
                                                   dvelectrostatic, dv_dboundary)
                !
                dvsoftcavity%of_r = dv_dboundary%of_r * this%solvent%dscaled%of_r
            END IF
            !
            CALL mapping%to_small(dvsoftcavity, aux)
            !
            dv(:) = dv(:) + aux%of_r(:)
            !
            CALL dv_dboundary%destroy()
            !
            CALL dvsoftcavity%destroy()
            !
        END IF
        !
        IF (this%setup%lelectrostatic) CALL dvelectrostatic%destroy()
        !
        CALL aux%destroy()
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE calc_dvenviron
    !------------------------------------------------------------------------------------
    !>
    !! Calculates the energy corrections in PW calculations
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE calc_deenviron(this, total_energy)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        CLASS(environ_obj), INTENT(INOUT) :: this
        REAL(DP), INTENT(INOUT) :: total_energy
        !
        !--------------------------------------------------------------------------------
        !
        this%deenviron = -this%system_electrons%density%scalar_product(this%dvtot)
        total_energy = total_energy + this%deenviron
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE calc_deenviron
    !------------------------------------------------------------------------------------
    !------------------------------------------------------------------------------------
    !
    !                               PRIVATE HELPER METHODS
    !
    !------------------------------------------------------------------------------------
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE environ_init_potential(this)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        CLASS(environ_obj), TARGET, INTENT(INOUT) :: this
        !
        CHARACTER(LEN=80) :: local_label
        !
        TYPE(environ_cell), POINTER :: system_cell, environment_cell
        !
        CHARACTER(LEN=80) :: sub_name = 'environ_init_potential'
        !
        !--------------------------------------------------------------------------------
        !
        system_cell => this%setup%system_cell
        environment_cell => this%setup%environment_cell
        !
        !--------------------------------------------------------------------------------
        ! Create local storage for base potential, that needs to be modified
        !
        local_label = 'vzero'
        !
        CALL this%vzero%init(system_cell, local_label)
        !
        local_label = 'dvtot'
        !
        CALL this%dvtot%init(system_cell, local_label)
        !
        !--------------------------------------------------------------------------------
        ! Electrostatic contribution
        !
        IF (this%setup%lelectrostatic) THEN
            local_label = 'velectrostatic'
            !
            CALL this%velectrostatic%init(environment_cell, local_label)
            !
            local_label = 'vreference'
            !
            CALL this%vreference%init(system_cell, local_label)
            !
        END IF
        !
        !--------------------------------------------------------------------------------
        ! Contribution to the potential due to boundary
        !
        IF (this%setup%lsoftcavity) THEN
            local_label = 'vsoftcavity'
            !
            CALL this%vsoftcavity%init(environment_cell, local_label)
            !
        END IF
        !
        !--------------------------------------------------------------------------------
        ! Confinement contribution
        !
        IF (this%setup%lconfine) THEN
            local_label = 'vconfine'
            !
            CALL this%vconfine%init(environment_cell, local_label)
            !
        END IF
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE environ_init_potential
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE environ_init_physical(this, nelec, nat, ntyp, atom_label, ityp, zv)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        INTEGER, INTENT(IN) :: nelec, nat, ntyp
        INTEGER, INTENT(IN) :: ityp(nat)
        REAL(DP), INTENT(IN) :: zv(ntyp)
        CHARACTER(LEN=3), INTENT(IN) :: atom_label(:)
        !
        CLASS(environ_obj), TARGET, INTENT(INOUT) :: this
        !
        CHARACTER(LEN=80) :: local_label
        !
        TYPE(environ_cell), POINTER :: system_cell, environment_cell
        !
        CHARACTER(LEN=80) :: sub_name = 'environ_init_physical'
        !
        !--------------------------------------------------------------------------------
        !
        system_cell => this%setup%system_cell
        environment_cell => this%setup%environment_cell
        !
        !--------------------------------------------------------------------------------
        ! Response
        !
        IF (this%setup%loptical) THEN
            !
            CALL this%system_response_electrons%init(0, system_cell)
            !
            CALL this%system_response_charges%init(system_cell)
            !
            CALL this%system_response_charges%add( &
                electrons=this%system_response_electrons)
            !
            CALL this%environment_response_electrons%init(0, environment_cell)
            !
            CALL this%environment_response_charges%init(environment_cell)
            !
            CALL this%environment_response_charges%add( &
                electrons=this%environment_response_electrons, &
                dielectric=this%optical)
            !
        END IF
        !
        !--------------------------------------------------------------------------------
        ! Ions
        !
        CALL this%system_ions%init(nat, ntyp, atom_label, ityp, zv, atomicspread, &
                                   corespread, solvationrad, radius_mode, &
                                   this%setup%lsoftcavity, this%setup%lsmearedions, &
                                   this%setup%lcoredensity, system_cell)
        !
        CALL this%environment_ions%init(nat, ntyp, atom_label, ityp, zv, atomicspread, &
                                        corespread, solvationrad, radius_mode, &
                                        this%setup%lsoftcavity, this%setup%lsmearedions, &
                                        this%setup%lcoredensity, environment_cell)
        !
        !--------------------------------------------------------------------------------
        ! Electrons
        !
        CALL this%system_electrons%init(nelec, system_cell)
        !
        CALL this%environment_electrons%init(nelec, environment_cell)
        !
        !--------------------------------------------------------------------------------
        ! System
        !
        CALL this%system_system%init(system_ntyp, system_dim, system_axis, &
                                     this%system_ions)
        !
        CALL this%environment_system%init(system_ntyp, system_dim, system_axis, &
                                          this%environment_ions)
        !
        !--------------------------------------------------------------------------------
        ! Free charges (if computing electrostatics or confinement)
        !
        CALL this%system_charges%init(system_cell)
        !
        CALL this%environment_charges%init(environment_cell)
        !
        IF (this%setup%lelectrostatic .OR. this%setup%lconfine) THEN
            !
            CALL this%system_charges%add(electrons=this%system_electrons)
            !
            CALL this%environment_charges%add(electrons=this%environment_electrons)
            !
        END IF
        !
        IF (this%setup%lelectrostatic) THEN
            !
            CALL this%system_charges%add(ions=this%system_ions)
            !
            CALL this%environment_charges%add(ions=this%environment_ions)
            !
        END IF
        !
        !--------------------------------------------------------------------------------
        ! External charges
        !
        IF (this%setup%lexternals) THEN
            !
            CALL this%externals%init(env_external_charges, extcharge_dim, &
                                     extcharge_axis, extcharge_pos, &
                                     extcharge_spread, extcharge_charge, &
                                     environment_cell)
            !
            CALL this%environment_charges%add(externals=this%externals)
            !
            DEALLOCATE (extcharge_axis)
            DEALLOCATE (extcharge_dim)
            DEALLOCATE (extcharge_spread)
            DEALLOCATE (extcharge_charge)
        END IF
        !
        !--------------------------------------------------------------------------------
        ! Solvent boundary
        !
        IF (this%setup%lsolvent) THEN
            local_label = 'solvent'
            !
            CALL this%solvent%init( &
                this%setup%lgradient, this%setup%need_factsqrt, this%setup%lsurface, &
                solvent_mode, stype, rhomax, rhomin, tbeta, env_static_permittivity, &
                alpha, softness, solvent_distance, solvent_spread, solvent_radius, &
                radial_scale, radial_spread, filling_threshold, filling_spread, &
                field_awareness, charge_asymmetry, field_max, field_min, &
                this%environment_electrons, this%environment_ions, &
                this%environment_system, this%setup%derivatives, environment_cell, &
                local_label)
            !
        END IF
        !
        !--------------------------------------------------------------------------------
        ! Electrolyte
        !
        IF (this%setup%lelectrolyte) THEN
            !
            CALL this%electrolyte%init( &
                env_electrolyte_ntyp, electrolyte_mode, stype, electrolyte_rhomax, &
                electrolyte_rhomin, electrolyte_tbeta, env_static_permittivity, &
                electrolyte_alpha, electrolyte_softness, electrolyte_distance, &
                electrolyte_spread, solvent_radius, radial_scale, radial_spread, &
                filling_threshold, filling_spread, field_awareness, charge_asymmetry, &
                field_max, field_min, this%environment_electrons, this%environment_ions, &
                this%environment_system, this%setup%derivatives, temperature, cion, &
                cionmax, rion, zion, electrolyte_entropy, electrolyte_linearized, &
                environment_cell)
            !
            CALL this%environment_charges%add(electrolyte=this%electrolyte)
            !
        END IF
        !
        !--------------------------------------------------------------------------------
        ! Semiconductor
        !
        IF (this%setup%lsemiconductor) THEN
            !
            CALL this%semiconductor%init(temperature, sc_permittivity, &
                                         sc_carrier_density, sc_electrode_chg, &
                                         sc_distance, sc_spread, sc_chg_thr, &
                                         this%environment_system, environment_cell)
            !
            CALL this%environment_charges%add(semiconductor=this%semiconductor)
            !
        END IF
        !
        !--------------------------------------------------------------------------------
        ! Dielectric
        !
        IF (this%setup%lstatic) THEN
            !
            CALL this%static%init(env_static_permittivity, this%solvent, &
                                  this%setup%need_gradient, this%setup%need_factsqrt, &
                                  this%setup%need_auxiliary, env_dielectric_regions, &
                                  environment_cell)
            !
            IF (this%static%nregions > 0) &
                CALL this%static%set_regions(env_dielectric_regions, epsregion_dim, &
                                             epsregion_axis, epsregion_pos, &
                                             epsregion_width, epsregion_spread, &
                                             epsregion_eps(1, :))
            !
            CALL this%environment_charges%add(dielectric=this%static)
            !
        END IF
        !
        IF (this%setup%loptical) THEN
            !
            CALL this%optical%init(env_optical_permittivity, this%solvent, &
                                   this%setup%need_gradient, this%setup%need_factsqrt, &
                                   this%setup%need_auxiliary, env_dielectric_regions, &
                                   environment_cell)
            !
            IF (this%optical%nregions > 0) &
                CALL this%optical%set_regions(env_dielectric_regions, epsregion_dim, &
                                              epsregion_axis, epsregion_pos, &
                                              epsregion_width, epsregion_spread, &
                                              epsregion_eps(2, :))
            !
        END IF
        !
        IF (ALLOCATED(epsregion_axis)) DEALLOCATE (epsregion_axis)
        !
        IF (ALLOCATED(epsregion_dim)) DEALLOCATE (epsregion_dim)
        !
        IF (ALLOCATED(epsregion_width)) DEALLOCATE (epsregion_width)
        !
        IF (ALLOCATED(epsregion_spread)) DEALLOCATE (epsregion_spread)
        !
        IF (ALLOCATED(epsregion_eps)) DEALLOCATE (epsregion_eps)
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE environ_init_physical
    !------------------------------------------------------------------------------------
    !
    !------------------------------------------------------------------------------------
END MODULE class_environ
!----------------------------------------------------------------------------------------
