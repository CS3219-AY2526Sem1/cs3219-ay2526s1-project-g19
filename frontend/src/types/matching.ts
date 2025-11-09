export interface MatchingSelections {
  topics: string[];
  difficulty: string[];
  primary_lang: string | null;
  secondary_lang: string[];
  proficiency: number;
}

export interface MatchResponse {
  status: string;
  queue_id: string;
  timeout: number;
}

export interface MatchedSelections {
  topic: string;
  difficulty: string;
  language: string;
}

export interface SessionData {
  session_id: string;
  user_id_list: string[];
  question_id: string;
  title: string;
  statement_md: string;
  assets: string[];
  topics: string[];
  difficulty: string;
  language: string;
  company_tags: string[];
  examples: string[];
  constraints: string[];
  timestamp: number;
}

export interface WebSocketMessage {
  status: 'success' | 'timeout' | 'relax';
  session: SessionData | null;
  message?: string; // Error messages
}
