import { Injectable } from '@angular/core';
type Theme = 'light' | 'dark';

@Injectable({ providedIn: 'root' })
export class ThemeService {
  private readonly KEY = 'theme';

  init(): void {
    const saved = localStorage.getItem(this.KEY) as Theme | null;
    if (saved) return this.apply(saved);

    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    document.documentElement.setAttribute('data-theme', prefersDark ? 'dark' : 'light');

    // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
    const mm = window.matchMedia?.('(prefers-color-scheme: dark)');
    // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
    if (mm) {
      mm.addEventListener('change', e => {
        if (!localStorage.getItem(this.KEY)) {
          document.documentElement.setAttribute('data-theme', e.matches ? 'dark' : 'light');
        }
      });
    }
  }

  apply(theme: Theme): void {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem(this.KEY, theme);
  }

  clearPreference(): void {
    localStorage.removeItem(this.KEY);
    this.init();
  }

  toggle(): void {
    const cur = document.documentElement.getAttribute('data-theme') as Theme;
    this.apply(cur === 'dark' ? 'light' : 'dark');
  }

  isDark(): boolean {
    return (document.documentElement.getAttribute('data-theme') || 'light') === 'dark';
  }
}
