import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient, HttpClientModule } from '@angular/common/http';
import { NgbTooltip } from '@ng-bootstrap/ng-bootstrap';
import { FaIconComponent } from '@fortawesome/angular-fontawesome';

import { provideHttpClient, withInterceptorsFromDi } from '@angular/common/http';

@Component({
  selector: 'jhi-home',
  standalone: true,
  imports: [CommonModule, FormsModule, NgbTooltip, FaIconComponent],
  // providers: [provideHttpClient(withInterceptorsFromDi())],
  templateUrl: './home.component.html',
  styleUrls: ['./home.component.scss'],
})
export class HomeComponent {
  year = new Date().getFullYear();
  loading = false;
  result: any = null;
  threshold = 0.5;

  form: any = {
    age: 65,
    sex: 1,
    anaemia: 0,
    diabetes: 1,
    ejection_fraction: 35,
    high_blood_pressure: 1,
    platelets: 250000,
    creatinine_phosphokinase: 200,
    serum_creatinine: 1.2,
    serum_sodium: 138,
    smoking: 0,
    time: 50,
  };

  constructor(private http: HttpClient) {}

  onSubmit(): void {
    this.loading = true;
    this.result = null;
    this.http.post<any>('/api/predict', { person: this.form, threshold: this.threshold }).subscribe({
      next: r => {
        this.result = r;
        this.loading = false;
      },
      error: _ => {
        alert('Prediction failed');
        this.loading = false;
      },
    });
  }
}
