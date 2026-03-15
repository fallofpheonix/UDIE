import { Injectable } from '@nestjs/common';
import { randomBytes, scryptSync } from 'node:crypto';
import { UserRole } from '../../common/enums/user-role.enum';
import { CreateUserDto } from './dto/create-user.dto';
import { UsersRepository } from './users.repository';
import { StoredUserEntity, UserEntity } from './entities/user.entity';

function hashPassword(password: string): string {
    const salt = randomBytes(16).toString('hex');
    const derivedKey = scryptSync(password, salt, 64).toString('hex');
    return `scrypt:${salt}:${derivedKey}`;
}

@Injectable()
export class UsersService {
    constructor(private readonly usersRepository: UsersRepository) { }

    async findAll(): Promise<UserEntity[]> {
        return this.usersRepository.findAll();
    }

    async findOneByEmail(email: string): Promise<StoredUserEntity | null> {
        return this.usersRepository.findByEmail(email);
    }

    async findOneById(id: string): Promise<UserEntity | null> {
        return this.usersRepository.findById(id);
    }

    async create(user: CreateUserDto): Promise<UserEntity> {
        return this.usersRepository.create({
            email: user.email,
            password_hash: hashPassword(user.password),
            role: user.role ?? UserRole.USER,
            full_name: user.full_name ?? null,
        });
    }

    async updateRole(id: string, role: string): Promise<void> {
        return this.usersRepository.updateRole(id, role);
    }

    async delete(id: string): Promise<void> {
        return this.usersRepository.delete(id);
    }
}
