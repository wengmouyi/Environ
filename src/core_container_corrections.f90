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
! Authors: Edan Bainglass (Department of Physics, UNT)
!
!----------------------------------------------------------------------------------------
!>
!!
!----------------------------------------------------------------------------------------
MODULE class_core_container_corrections
    !------------------------------------------------------------------------------------
    !
    USE class_io, ONLY: io
    !
    USE environ_param, ONLY: DP
    !
    USE class_density
    USE class_gradient
    USE class_function
    !
    USE class_core_container
    USE class_core_1da_electrostatics
    !
    USE class_electrolyte_base
    USE class_semiconductor_base
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
    TYPE, EXTENDS(core_container), PUBLIC :: container_corrections
        !--------------------------------------------------------------------------------
        !
        !--------------------------------------------------------------------------------
    CONTAINS
        !--------------------------------------------------------------------------------
        !
        PROCEDURE, PRIVATE :: calc_vperiodic, calc_vgcs, calc_vms
        GENERIC :: potential => calc_vperiodic, calc_vgcs, calc_vms
        !
        PROCEDURE, PRIVATE :: calc_gradvperiodic, calc_gradvgcs, calc_gradvms
        GENERIC :: gradpotential => calc_gradvperiodic, calc_gradvgcs, calc_gradvms
        !
        PROCEDURE :: force => calc_fperiodic
        !
        !--------------------------------------------------------------------------------
    END TYPE container_corrections
    !------------------------------------------------------------------------------------
    !
    !------------------------------------------------------------------------------------
CONTAINS
    !------------------------------------------------------------------------------------
    !------------------------------------------------------------------------------------
    !
    !                                 CORRECTION METHODS
    !
    !------------------------------------------------------------------------------------
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE calc_vperiodic(this, charges, gradv)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_density), INTENT(IN) :: charges
        !
        CLASS(container_corrections), INTENT(INOUT) :: this
        TYPE(environ_density), INTENT(INOUT) :: gradv
        !
        CHARACTER(LEN=80) :: sub_name = 'calc_vperiodic'
        !
        !--------------------------------------------------------------------------------
        !
        SELECT TYPE (core => this%core)
            !
        TYPE IS (core_1da_electrostatics)
            CALL core%calc_1da_vperiodic(charges, gradv)
            !
        CLASS DEFAULT
            CALL io%error(sub_name, 'Unexpected core', 1)
            !
        END SELECT
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE calc_vperiodic
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE calc_gradvperiodic(this, charges, gvtot)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_density), INTENT(IN) :: charges
        !
        CLASS(container_corrections), INTENT(INOUT) :: this
        TYPE(environ_gradient), INTENT(INOUT) :: gvtot
        !
        CHARACTER(LEN=80) :: sub_name = 'calc_gradvperiodic'
        !
        !--------------------------------------------------------------------------------
        !
        SELECT TYPE (core => this%core)
            !
        TYPE IS (core_1da_electrostatics)
            CALL core%calc_1da_gradvperiodic(charges, gvtot)
            !
        CLASS DEFAULT
            CALL io%error(sub_name, 'Unexpected core', 1)
            !
        END SELECT
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE calc_gradvperiodic
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE calc_fperiodic(this, natoms, ions, auxiliary, f)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        INTEGER, INTENT(IN) :: natoms
        CLASS(environ_function), INTENT(IN) :: ions(:)
        TYPE(environ_density), INTENT(IN) :: auxiliary
        !
        CLASS(container_corrections), INTENT(INOUT) :: this
        REAL(DP), INTENT(INOUT) :: f(3, natoms)
        !
        CHARACTER(LEN=80) :: sub_name = 'calc_fperiodic'
        !
        !--------------------------------------------------------------------------------
        !
        SELECT TYPE (core => this%core)
            !
        TYPE IS (core_1da_electrostatics)
            CALL core%calc_1da_fperiodic(natoms, ions, auxiliary, f)
            !
        CLASS DEFAULT
            CALL io%error(sub_name, 'Unexpected core', 1)
            !
        END SELECT
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE calc_fperiodic
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE calc_vgcs(this, electrolyte, charges, potential)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_electrolyte_base), INTENT(IN) :: electrolyte
        TYPE(environ_density), INTENT(IN) :: charges
        !
        CLASS(container_corrections), INTENT(INOUT) :: this
        TYPE(environ_density), INTENT(INOUT) :: potential
        !
        CHARACTER(LEN=80) :: sub_name = 'calc_vgcs'
        !
        !--------------------------------------------------------------------------------
        !
        SELECT TYPE (core => this%core)
            !
        TYPE IS (core_1da_electrostatics)
            CALL core%calc_1da_vgcs(electrolyte, charges, potential)
            !
        CLASS DEFAULT
            CALL io%error(sub_name, 'Unexpected core', 1)
            !
        END SELECT
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE calc_vgcs
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE calc_gradvgcs(this, electrolyte, charges, gradv)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_electrolyte_base), INTENT(IN) :: electrolyte
        TYPE(environ_density), INTENT(IN) :: charges
        !
        CLASS(container_corrections), INTENT(INOUT) :: this
        TYPE(environ_gradient), INTENT(INOUT) :: gradv
        !
        CHARACTER(LEN=80) :: sub_name = 'calc_gradvgcs'
        !
        !--------------------------------------------------------------------------------
        !
        SELECT TYPE (core => this%core)
            !
        TYPE IS (core_1da_electrostatics)
            CALL core%calc_1da_gradvgcs(electrolyte, charges, gradv)
            !
        CLASS DEFAULT
            CALL io%error(sub_name, 'Unexpected core', 1)
            !
        END SELECT
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE calc_gradvgcs
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE calc_vms(this, semiconductor, charges, potential)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_semiconductor_base), INTENT(IN) :: semiconductor
        TYPE(environ_density), INTENT(IN) :: charges
        !
        CLASS(container_corrections), INTENT(INOUT) :: this
        TYPE(environ_density), INTENT(INOUT) :: potential
        !
        CHARACTER(LEN=80) :: sub_name = 'calc_vms'
        !
        !--------------------------------------------------------------------------------
        !
        SELECT TYPE (core => this%core)
            !
        TYPE IS (core_1da_electrostatics)
            CALL core%calc_1da_vms(semiconductor, charges, potential)
            !
        CLASS DEFAULT
            CALL io%error(sub_name, 'Unexpected core', 1)
            !
        END SELECT
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE calc_vms
    !------------------------------------------------------------------------------------
    !>
    !!
    !------------------------------------------------------------------------------------
    SUBROUTINE calc_gradvms(this, semiconductor, charges, gradv)
        !--------------------------------------------------------------------------------
        !
        IMPLICIT NONE
        !
        TYPE(environ_semiconductor_base), INTENT(IN) :: semiconductor
        TYPE(environ_density), INTENT(IN) :: charges
        !
        CLASS(container_corrections), INTENT(INOUT) :: this
        TYPE(environ_gradient), INTENT(INOUT) :: gradv
        !
        CHARACTER(LEN=80) :: sub_name = 'calc_gradvms'
        !
        !--------------------------------------------------------------------------------
        !
        SELECT TYPE (core => this%core)
            !
        TYPE IS (core_1da_electrostatics)
            CALL core%calc_1da_gradvms(semiconductor, charges, gradv)
            !
        CLASS DEFAULT
            CALL io%error(sub_name, 'Unexpected core', 1)
            !
        END SELECT
        !
        !--------------------------------------------------------------------------------
    END SUBROUTINE calc_gradvms
    !------------------------------------------------------------------------------------
    !
    !------------------------------------------------------------------------------------
END MODULE class_core_container_corrections
!----------------------------------------------------------------------------------------
