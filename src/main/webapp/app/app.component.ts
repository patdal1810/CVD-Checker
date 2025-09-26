import { Component, OnInit, inject } from '@angular/core';
import { registerLocaleData } from '@angular/common';
import dayjs from 'dayjs/esm';
import { FaIconLibrary } from '@fortawesome/angular-fontawesome';
import { NgbDatepickerConfig } from '@ng-bootstrap/ng-bootstrap';
import locale from '@angular/common/locales/en';

import { ApplicationConfigService } from 'app/core/config/application-config.service';
import { ThemeService } from 'app/core/theme.service';
import { fontAwesomeIcons } from 'app/config/font-awesome-icons';
import MainComponent from 'app/layouts/main/main.component';

@Component({
  selector: 'jhi-app',
  standalone: true,
  template: '<jhi-main />',
  styleUrls: ['./app.component.scss'], // <-- keep this
  imports: [MainComponent],
})
export default class AppComponent implements OnInit {
  private readonly applicationConfigService = inject(ApplicationConfigService);
  private readonly iconLibrary = inject(FaIconLibrary);
  private readonly dpConfig = inject(NgbDatepickerConfig);

  constructor(public themeService: ThemeService) {
    this.applicationConfigService.setEndpointPrefix(SERVER_API_URL);
    registerLocaleData(locale);
    this.iconLibrary.addIcons(...fontAwesomeIcons);
    this.dpConfig.minDate = { year: dayjs().subtract(100, 'year').year(), month: 1, day: 1 };
  }

  ngOnInit(): void {
    this.themeService.init();
  }
}
