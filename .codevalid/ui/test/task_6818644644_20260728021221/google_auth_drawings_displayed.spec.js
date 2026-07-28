import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGoogleAuthenticatedSession,
  mockDrawingsList,
} from "../../helpers/mock-api.js";
import {
  googleDrawingsResponse,
} from "../../mock/mock-data.js";

test("Drawings are displayed and associated with Google identity after Google login", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "google_auth_drawings_displayed",
    testTitle: testInfo.title,
  });

  await recorder.step("Mock Google-authenticated session and drawings API");
  await mockGoogleAuthenticatedSession(page);
  await mockDrawingsList(page, googleDrawingsResponse);

  await recorder.step("Open draw page and verify Google sign-in entry point");
  await page.goto("/draw");
  await expect(page.getByRole("button", { name: "Sign-in with Google" })).toBeVisible();

  await recorder.step("Trigger Google sign-in and load drawings index page");
  await Promise.all([
    page.waitForURL(/\/$/),
    page.goto("/"),
  ]);

  await recorder.step("Assert Google drawings and identity metadata are visible");
  await expect(page.getByRole("img", { name: "Google drawing" })).toBeVisible();
  await expect(page.getByText("Google User")).toBeVisible();
  await expect(page.getByRole("img", { name: "AI image generated of Google drawing" })).toBeVisible();
  await expect(page.getByRole("img", { name: "GitHub drawing" })).toHaveCount(0);
  await expect(page.getByText("GitHub User")).toHaveCount(0);

  console.log("CODEVALID_TEST_ASSERTION_OK:google_auth_drawings_displayed");
  await recorder.save(testInfo);
});
