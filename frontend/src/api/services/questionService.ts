import { questionClient } from '../client';

export const questionService = {
  getTopics: async (): Promise<string[]> => {
    try {
      const response = await questionClient.get<{ topics: string[] }>('/api/topics');
      return response.data.topics ?? [];
    } catch (error) {
      console.warn('Failed to fetch topics from question service API:', error);
      return [];
    }
  },
  getDifficulties: async (): Promise<string[]> => {
    try {
      const response = await questionClient.get<{ difficulties: string[] }>('/api/difficulty');
      return response.data.difficulties ?? [];
    } catch (error) {
      console.warn('Failed to fetch difficulties from question service API:', error);
      return [];
    }
  },
  getQuestion: async (questionId: string) => {
    try {
      const response = await questionClient.get(`/api/questions/${questionId}`);
      return response.data;
    } catch (error) {
      console.warn(`Error fetching question with ID ${questionId}:`, error);
      return null;
    }
  },
  getQuestions: async (params?: {
    page?: number;
    page_size?: number;
    search?: string;
    difficulty?: string[];
    topics?: string[];
    sort?: string;
    order?: string;
  }) => {
    try {
      const response = await questionClient.get('/api/questions', { params });
      return response.data;
    } catch (error) {
      console.error('Error fetching questions:', error);
      throw error;
    }
  },
};
