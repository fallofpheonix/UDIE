import { Body, Controller, Delete, Get, Param, Patch, Post } from '@nestjs/common';
import { UsersService } from './users.service';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserRoleDto } from './dto/update-user-role.dto';
import { UserEntity } from './entities/user.entity';

@Controller('users')
export class UsersController {
    constructor(private readonly usersService: UsersService) { }

    @Get()
    async findAll(): Promise<UserEntity[]> {
        return this.usersService.findAll();
    }

    @Post()
    async create(@Body() createUserDto: CreateUserDto): Promise<UserEntity> {
        // In a real app, we would hash the password here.
        // For this context, we'll store it as provided or mock hash.
        return this.usersService.create({
            ...createUserDto,
            password_hash: `mock_hash_${createUserDto.password}`,
        });
    }

    @Patch(':id/role')
    async updateRole(
        @Param('id') id: string,
        @Body() updateRoleDto: UpdateUserRoleDto,
    ): Promise<void> {
        return this.usersService.updateRole(id, updateRoleDto.role);
    }

    @Delete(':id')
    async delete(@Param('id') id: string): Promise<void> {
        return this.usersService.delete(id);
    }
}
