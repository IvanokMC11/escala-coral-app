export interface Member {
  id: number;
  name: string;
  email: string | null;
  phone: string | null;
  role: 'admin' | 'member';
  is_active: number;
  created_at: string;
  updated_at: string;
}

export interface AuthUser {
  id: number;
  member_id: number;
  email: string;
  role: 'admin' | 'member';
  name: string;
}

export interface Rehearsal {
  id: number;
  date: string;
  start_time: string;
  end_time: string;
  description: string | null;
  created_at: string;
  updated_at: string;
}

export interface Attendance {
  id: number;
  member_id: number;
  rehearsal_id: number;
  arrival_time: string;
  status: 'present' | 'late' | 'absent';
  late_minutes: number;
  fine_amount: number;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface AttendanceWithMember extends Attendance {
  member_name: string;
}

export interface Settings {
  [key: string]: string;
}

export interface MonthlyReport {
  member_id: number;
  member_name: string;
  total_rehearsals: number;
  present_count: number;
  late_count: number;
  absent_count: number;
  total_late_minutes: number;
  total_fine: number;
  attendance_percentage: number;
}

export interface D1Result<T> {
  results: T[];
  success: boolean;
  error?: string;
}

export interface Env {
  DB: D1Database;
  JWT_SECRET: string;
}
