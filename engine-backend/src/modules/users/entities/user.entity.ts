import { UserRole } from '../../../common/enums/user-role.enum';

export interface UserEntity {
    id: string;
    email: string;
    role: UserRole;
    full_name: string | null;
    created_at: Date;
    updated_at: Date;
}

export interface StoredUserEntity extends UserEntity {
    password_hash: string;
}
