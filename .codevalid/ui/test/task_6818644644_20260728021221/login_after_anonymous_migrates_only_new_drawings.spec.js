import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockAnonymousOnlySession,
  mockGoogleAuthenticatedSession,
  mockDrawingsList,
} from "../../helpers/mock-api.js";
import {
  anonymousDrawingsResponse,
  googleDrawingsResponse,
} from "../../mock/mock-data.js";

test("Logging in after anonymous session does not migrate previous anonymous drawings", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "login_after_anonymous_migrates_only_new_drawings",
    testTitle: testInfo.title,
  });

  await recorder.step("Start as anonymous user and verify anonymous drawings are visible");
  await mockAnonymousOnlySession(page);
  await mockDrawingsList(page, anonymousDrawingsResponse);
  await page.goto("/");
  await expect(page.getByRole("img", { name: "Anonymous drawing" })).toBeVisible();
  await expect(page.getByText("Anonymous User")).toBeVisible();

  await recorder.step("Switch to Google session and reload with only Google drawings");
  await mockGoogleAuthenticatedSession(page);
  await mockDrawingsList(page, googleDrawingsResponse);
  await page.goto("/");

  await recorder.step("Assert anonymous drawings are hidden after Google login");
  await expect(page.getByRole("img", { name: "Google drawing" })).toBeVisible();
  await expect(page.getByText("Google User")).toBeVisible();
  await expect(page.getByRole("img", { name: "Anonymous drawing" })).toHaveCount(0);
  await expect(page.getByText("Anonymous User")).toHaveCount(0);

  console.log("CODEVALID_TEST_ASSERTION_OK:login_after_anonymous_migrates_only_new_drawings");
  await recorder.save(testInfo);
});
