export interface User {
  id: string;
  email: string;
  display_name: string;
  phone_number: string;
  date_of_birth: string;
  is_verified: boolean;
  created_at: string;
  updated_at: string;
}

export interface UpdateUserDto {
  display_name?: string;
  phone_number?: string;
  date_of_birth?: string;
}
