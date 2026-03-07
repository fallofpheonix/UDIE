import { Injectable } from '@nestjs/common';
import { UsersRepository } from './users.repository';
import { UserEntity } from './entities/user.entity';

@Injectable()
export class UsersService {
    constructor(private readonly usersRepository: UsersRepository) { }

    async findAll(): Promise<UserEntity[]> {
        return this.usersRepository.findAll();
    }

    async findOneByEmail(email: string): Promise<UserEntity | null> {
        return this.usersRepository.findByEmail(email);
    }

    async findOneById(id: string): Promise<UserEntity | null> {
        return this.usersRepository.findById(id);
    }

    async create(user: Partial<UserEntity>): Promise<UserEntity> {
        return this.usersRepository.create(user);
    }

    async updateRole(id: string, role: string): Promise<void> {
        return this.usersRepository.updateRole(id, role);
    }

    async delete(id: string): Promise<void> {
        return this.usersRepository.delete(id);
    }
}
