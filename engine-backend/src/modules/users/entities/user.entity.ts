import { UserRole } from '../../../common/enums/user-role.enum';

export interface UserEntity {
    id: string;
    email: string;
    password_hash: string;
    role: UserRole;
    full_name: string | null;
    created_at: Date;
    updated_at: Date;
}
